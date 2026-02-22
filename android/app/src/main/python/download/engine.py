import threading
import queue
import time
from typing import Dict, Any, Optional
from initialization.bridge_logger import logger
from download.task import DownloadTask
from download.worker import download_worker

class DownloadEngine:
    """Manager for download tasks, queueing, and concurrency."""
    
    def __init__(self, max_concurrent=3):
        self._tasks: Dict[str, DownloadTask] = {}
        self._queue = queue.Queue()
        self._sem = threading.Semaphore(max_concurrent)
        self._lock = threading.Lock()
        
        # Start background threads
        threading.Thread(target=self._processor, daemon=True).start()
        threading.Thread(target=self._watchdog, daemon=True).start()
        logger.info(f" [DownloadEngine] Initialized with max_concurrent={max_concurrent}")

    def _processor(self):
        """Processes the task queue."""
        while True:
            tid, opts = self._queue.get()
            threading.Thread(target=self._worker_thread, args=(tid, opts), daemon=True).start()

    def _worker_thread(self, tid: str, opts: dict):
        """Wrapper for worker to handle semaphore and state transition."""
        with self._sem:
            with self._lock:
                task = self._tasks.get(tid)
                if not task or task.cancel_flag:
                    self._queue.task_done()
                    return
                task.status = "downloading"
            
            # Run the actual work (Native mode)
            download_worker(task)
            self._queue.task_done()

    def _watchdog(self):
        """Monitors stuck downloads."""
        while True:
            time.sleep(15)
            with self._lock:
                now = time.time()
                for tid, task in list(self._tasks.items()):
                    if task.status == "downloading" and (now - task.last_update > 90):
                        logger.warning(f" [Watchdog] Task {tid} timed out, marking as error")
                        task.cancel_flag = True
                        task.status = "error"
                        task.error = "Download timed out (no activity for 90s)"

    def add_task(self, url: str, opts: dict, info: Optional[dict] = None) -> str:
        """Add a new task to the queue."""
        tid = str(int(time.time() * 1000))
        task = DownloadTask(tid, url, info)
        
        # Apply configuration options to task
        if opts:
            # Format selection
            task.format_ids = opts.get('formatIds') or opts.get('formatId') or opts.get('format_ids') or opts.get('format')
            
            # Download type
            task.download_type = opts.get('downloadType') or opts.get('download_type', 'video')
            
            # Output directory
            task.output_dir = opts.get('outputDir') or opts.get('output_dir')
            
            # Metadata embedding
            embed_metadata = opts.get('embedMetadata')
            if embed_metadata is None: embed_metadata = opts.get('embed_metadata')
            if embed_metadata is not None: task.embed_metadata = embed_metadata
            
            # Cookies
            task.cookies = opts.get('cookies')
        
        with self._lock:
            self._tasks[tid] = task
        
        self._queue.put((tid, opts))
        logger.info(f" [DownloadEngine] Added task {tid}")
        return tid

    def get_status(self, tid: str) -> Dict[str, Any]:
        """Get status of a specific task."""
        with self._lock:
            task = self._tasks.get(tid)
            return task.to_dict() if task else {}

    def cancel_task(self, tid: str) -> bool:
        """Cancel a running or queued task."""
        with self._lock:
            if tid in self._tasks:
                self._tasks[tid].cancel_flag = True
                logger.info(f" [DownloadEngine] Cancelled task {tid}")
                return True
        return False

# Singleton instance
download_engine = DownloadEngine()
