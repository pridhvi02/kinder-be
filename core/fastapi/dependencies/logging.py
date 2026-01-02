from fastapi import BackgroundTasks, Request
import logging
from datetime import datetime

logger = logging.getLogger(__name__)


class Logging:
    def __init__(self, background_task: BackgroundTasks, request: Request = None):
        self.request = request
        background_task.add_task(self._send_log)

    async def _send_log(self):
        """
        Background task to log request information.
        Currently logs to console; can be extended to send to external logging service.
        """
        if self.request:
            log_data = {
                "timestamp": datetime.utcnow().isoformat(),
                "method": self.request.method,
                "path": self.request.url.path,
                "client": self.request.client.host if self.request.client else None,
            }
            logger.info("Request Log: %s", log_data)
        else:
            logger.info("Logging task executed at %s", datetime.utcnow().isoformat())
