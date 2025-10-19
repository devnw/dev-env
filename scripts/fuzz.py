#!/usr/bin/env python3
"""
Enhanced multi-language fuzz testing script with reliable parallel execution.

Features:
- Automatic fuzz test discovery across all Go packages
- Robust parallel execution with proper job management
- Real-time progress reporting and comprehensive error handling
- Configurable failure handling and resource management
"""

import argparse
import asyncio
import glob
import logging
import os
import re
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Dict, List, NamedTuple, Optional, Tuple


class FuzzTarget(NamedTuple):
    """Represents a single fuzz test target."""
    directory: str
    function: str
    file_path: str


class FuzzResult(NamedTuple):
    """Represents the result of a fuzz test execution."""
    target: FuzzTarget
    success: bool
    duration: float
    output: str
    error: str


class FuzzConfig:
    """Configuration for fuzz testing."""
    
    def __init__(self):
        self.fuzz_time: int = 10
        self.jobs: int = 0  # Auto-detect
        self.error_file: Optional[str] = None
        self.continue_on_failure: bool = False
        self.verbose: bool = False
        self.config_dir: str = "./shared"
        
    @classmethod
    def from_env_and_args(cls) -> 'FuzzConfig':
        """Create config from environment variables and command line arguments."""
        config = cls()
        
        # Load from environment variables
        config.fuzz_time = int(os.environ.get('FUZZ_TIME', config.fuzz_time))
        config.jobs = int(os.environ.get('FUZZ_JOBS', config.jobs)) if os.environ.get('FUZZ_JOBS') else config.jobs
        config.error_file = os.environ.get('FUZZ_ERROR_FILE', config.error_file)
        config.continue_on_failure = os.environ.get('FUZZ_CONTINUE_ON_FAILURE', '').lower() == 'true'
        config.verbose = os.environ.get('FUZZ_VERBOSE', '').lower() == 'true'
        config.config_dir = os.environ.get('FUZZ_CONFIG_DIR', config.config_dir)
        
        # Parse command line arguments
        parser = argparse.ArgumentParser(
            description='Enhanced Go Fuzz Testing with Parallel Execution',
            formatter_class=argparse.RawDescriptionHelpFormatter,
            epilog="""
EXAMPLES:
    # Basic usage (auto-detects cores, 10s per test)
    %(prog)s
    
    # Development workflow (quick feedback)
    %(prog)s -t 5 -c
    
    # CI/CD testing (moderate duration with error logging)
    %(prog)s -t 30 -c -e ci_fuzz_errors.log
    
    # Comprehensive testing (extended duration, verbose)
    %(prog)s -t 120 -j 4 -v -e comprehensive_fuzz.log

ENVIRONMENT VARIABLES:
    FUZZ_TIME                  Default fuzz time in seconds
    FUZZ_JOBS                  Default number of parallel jobs
    FUZZ_ERROR_FILE            Default error file path
    FUZZ_CONTINUE_ON_FAILURE   Continue on failures (true/false)
    FUZZ_VERBOSE               Enable verbose output (true/false)
    FUZZ_CONFIG_DIR            Configuration directory
            """
        )
        
        parser.add_argument('-t', '--time', type=int, metavar='SECONDS',
                          help=f'Fuzz time per test in seconds (default: {config.fuzz_time})')
        parser.add_argument('-j', '--jobs', type=int, metavar='N',
                          help='Number of parallel fuzz tests (default: auto-detect, limited for efficiency)')
        parser.add_argument('-e', '--error-file', metavar='FILE',
                          help='Write errors to file and tee to stderr simultaneously')
        parser.add_argument('-c', '--continue-on-failure', action='store_true',
                          help='Continue on fuzz test failures (don\'t exit early)')
        parser.add_argument('-v', '--verbose', action='store_true',
                          help='Enable verbose output with detailed execution info')
        parser.add_argument('--config-dir', metavar='DIR',
                          help=f'Configuration directory (default: {config.config_dir})')
        
        args = parser.parse_args()
        
        # Override with command line arguments
        if args.time is not None:
            config.fuzz_time = args.time
        if args.jobs is not None:
            config.jobs = args.jobs
        if args.error_file is not None:
            config.error_file = args.error_file
        if args.continue_on_failure:
            config.continue_on_failure = True
        if args.verbose:
            config.verbose = True
        if args.config_dir is not None:
            config.config_dir = args.config_dir
            
        return config


class FuzzRunner:
    """Main fuzz test runner with parallel execution."""
    
    def __init__(self, config: FuzzConfig):
        self.config = config
        self.logger = self._setup_logging()
        self.cpu_cores = os.cpu_count() or 4
        self.jobs = self._determine_jobs()
        self.error_file_handle = None
        
        if config.error_file:
            error_file_path = os.path.abspath(config.error_file)
            self.logger.debug(f"Opening error file: {error_file_path}")
            self.error_file_handle = open(error_file_path, 'w')
            self.logger.debug(f"Error file handle created: {self.error_file_handle is not None}")
    
    def __enter__(self):
        return self
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.error_file_handle:
            self.error_file_handle.close()
    
    def _setup_logging(self) -> logging.Logger:
        """Setup logging configuration."""
        logger = logging.getLogger('fuzz')
        logger.setLevel(logging.DEBUG if self.config.verbose else logging.INFO)
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.DEBUG if self.config.verbose else logging.INFO)
        
        formatter = logging.Formatter('[%(levelname)s] %(message)s')
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)
        
        return logger
    
    def _determine_jobs(self) -> int:
        """Determine optimal number of parallel jobs."""
        if self.config.jobs > 0:
            self.logger.debug(f"Using user-specified {self.config.jobs} parallel fuzz jobs")
            return self.config.jobs
        
        # Auto-detect with conservative limits for fuzz tests
        if self.cpu_cores > 8:
            jobs = 4
        elif self.cpu_cores > 4:
            jobs = 2
        else:
            jobs = 1
        
        self.logger.debug(f"Detected {self.cpu_cores} CPU cores, using {jobs} parallel fuzz jobs")
        return jobs
    
    def _log_error(self, message: str):
        """Log error to both logger and error file if configured."""
        self.logger.error(message)
        if self.error_file_handle:
            self.logger.debug(f"Writing to error file: {message}")
            self.error_file_handle.write(f"[ERROR] {message}\n")
            self.error_file_handle.flush()
        else:
            self.logger.debug("No error file handle available")
    
    def discover_fuzz_targets(self) -> List[FuzzTarget]:
        """Discover all fuzz test functions in the current directory and subdirectories."""
        self.logger.debug("Searching for fuzz test files...")
        
        # Find all Go test files containing fuzz functions
        fuzz_files = []
        for test_file in glob.glob("**/*_test.go", recursive=True):
            try:
                with open(test_file, 'r') as f:
                    content = f.read()
                    if re.search(r'func\s+Fuzz\w*\s*\(', content):
                        fuzz_files.append(test_file)
            except Exception as e:
                self.logger.warning(f"Could not read {test_file}: {e}")
        
        if not fuzz_files:
            self.logger.info("No fuzz test files found")
            return []
        
        self.logger.debug(f"Found {len(fuzz_files)} fuzz test files")
        
        # Extract fuzz functions from each file
        targets = []
        for test_file in fuzz_files:
            try:
                with open(test_file, 'r') as f:
                    content = f.read()
                    
                # Find all fuzz function names
                fuzz_funcs = re.findall(r'func\s+(Fuzz\w*)\s*\(', content)
                parent_dir = os.path.dirname(test_file)
                
                for func in fuzz_funcs:
                    target = FuzzTarget(
                        directory=parent_dir if parent_dir else ".",
                        function=func,
                        file_path=test_file
                    )
                    targets.append(target)
                    
                    # Only show first few targets unless verbose
                    if self.config.verbose or len(targets) <= 5:
                        self.logger.debug(f"Found fuzz function: {func} in {test_file}")
                        
            except Exception as e:
                self.logger.warning(f"Could not parse {test_file}: {e}")
        
        return targets
    
    def _run_single_fuzz_test(self, target: FuzzTarget) -> FuzzResult:
        """Run a single fuzz test."""
        start_time = time.time()
        
        # Calculate GOMAXPROCS for this test
        gomaxprocs = max(1, self.cpu_cores // self.jobs)
        
        self.logger.debug(f"Starting fuzz test: {target.function} in {target.file_path}")
        self.logger.debug(f"Running with GOMAXPROCS={gomaxprocs}")
        self.logger.debug(f"Working directory: {os.getcwd()}")
        
        # Prepare environment
        env = os.environ.copy()
        env['GOMAXPROCS'] = str(gomaxprocs)
        
        # Build command - use module-relative path for Go modules
        # Check if we're in a Go module by looking for go.mod
        module_path = target.directory
        if os.path.exists("go.mod"):
            # In a Go module, use relative paths with ./ prefix
            if target.directory == ".":
                module_path = "."
            else:
                module_path = f"./{target.directory}"
        else:
            # Not in a Go module, use absolute directory paths
            module_path = target.directory
        
        cmd = [
            'go', 'test', module_path,
            f'-run=^{target.function}$',
            f'-fuzz=^{target.function}$',
            f'-fuzztime={self.config.fuzz_time}s'
        ]
        
        self.logger.debug(f"Command: {' '.join(cmd)}")
        
        try:
            # Run the test from project root
            result = subprocess.run(
                cmd,
                env=env,
                capture_output=True,
                text=True,
                cwd=os.getcwd(),  # Ensure we're in the project root
                timeout=self.config.fuzz_time + 60  # Add buffer for test overhead
            )
            
            duration = time.time() - start_time
            success = result.returncode == 0
            
            if success:
                self.logger.debug(f"Completed fuzz test: {target.function} in {target.file_path}")
            else:
                self._log_error(f"Failed fuzz test: {target.function} in {target.file_path}")
                if result.stderr:
                    self._log_error(f"Error output: {result.stderr}")
            
            return FuzzResult(
                target=target,
                success=success,
                duration=duration,
                output=result.stdout,
                error=result.stderr
            )
            
        except subprocess.TimeoutExpired:
            duration = time.time() - start_time
            error_msg = f"Fuzz test {target.function} timed out after {duration:.1f}s"
            self._log_error(error_msg)
            
            return FuzzResult(
                target=target,
                success=False,
                duration=duration,
                output="",
                error=error_msg
            )
            
        except Exception as e:
            duration = time.time() - start_time
            error_msg = f"Exception running fuzz test {target.function}: {e}"
            self._log_error(error_msg)
            
            return FuzzResult(
                target=target,
                success=False,
                duration=duration,
                output="",
                error=error_msg
            )
    
    def run_fuzz_tests(self, targets: List[FuzzTarget]) -> Dict[str, int]:
        """Run all fuzz tests with parallel execution."""
        if not targets:
            self.logger.info("No fuzz functions found")
            return {"completed": 0, "failed": 0}
        
        self.logger.info(f"Found {len(targets)} fuzz functions to test")
        self.logger.info(f"Running with {self.jobs} parallel jobs, {self.config.fuzz_time}s per test")
        self.logger.info(f"Each fuzz test will use up to {max(1, self.cpu_cores // self.jobs)} CPU cores (GOMAXPROCS)")
        
        if len(targets) > 50:
            self.logger.info("Large number of fuzz tests detected - this may take a while")
            if not self.config.verbose:
                self.logger.info("Consider using -v for verbose progress updates")
        
        completed = 0
        failed = 0
        
        # Use ThreadPoolExecutor for parallel execution
        with ThreadPoolExecutor(max_workers=self.jobs) as executor:
            # Submit all fuzz tests
            future_to_target = {
                executor.submit(self._run_single_fuzz_test, target): target 
                for target in targets
            }
            
            # Process completed tests as they finish
            for future in as_completed(future_to_target):
                target = future_to_target[future]
                
                try:
                    result = future.result()
                    completed += 1
                    
                    if not result.success:
                        failed += 1
                        
                        # Log failure details to error file
                        if self.config.error_file:
                            self._log_error(f"FAILED: {result.target.function} in {result.target.file_path}")
                            if result.error:
                                self._log_error(f"Details: {result.error}")
                            self._log_error("---")
                        
                        # Show error details for debugging
                        if result.error:
                            self.logger.debug(f"Error details for {result.target.function}: {result.error[:200]}...")
                        
                        # Stop on first failure if not continuing
                        if not self.config.continue_on_failure:
                            self.logger.error("Stopping due to failure (use -c to continue on failures)")
                            # Cancel remaining futures
                            for remaining_future in future_to_target:
                                if not remaining_future.done():
                                    remaining_future.cancel()
                            break
                    
                    # Progress update
                    remaining = len(targets) - completed
                    self.logger.info(f"Progress: {completed}/{len(targets)} completed, {failed} failed, {remaining} remaining")
                    
                except Exception as e:
                    self.logger.error(f"Exception processing result for {target.function}: {e}")
                    completed += 1
                    failed += 1
        
        return {"completed": completed, "failed": failed}
    
    def run(self) -> int:
        """Main entry point for fuzz testing."""
        try:
            # Discover fuzz targets
            targets = self.discover_fuzz_targets()
            
            # Run fuzz tests
            stats = self.run_fuzz_tests(targets)
            
            # Final summary
            self.logger.info(f"Fuzzing completed: {stats['completed']} total, {stats['failed']} failed")
            
            if stats['failed'] > 0:
                if self.config.error_file:
                    self._log_error(f"Total of {stats['failed']} fuzz tests failed")
                    self.logger.error(f"Errors have been logged to: {self.config.error_file}")
                
                if self.config.continue_on_failure:
                    self.logger.info("Some tests failed, but continuing as requested")
                    return 0
                else:
                    self.logger.error("Tests failed")
                    return 1
            
            self.logger.info("All fuzz tests completed successfully")
            return 0
            
        except KeyboardInterrupt:
            self.logger.info("Fuzz testing interrupted by user")
            return 130
        except Exception as e:
            self.logger.error(f"Unexpected error: {e}")
            return 1


def main():
    """Main entry point."""
    config = FuzzConfig.from_env_and_args()
    
    with FuzzRunner(config) as runner:
        exit_code = runner.run()
        sys.exit(exit_code)


if __name__ == '__main__':
    main()
