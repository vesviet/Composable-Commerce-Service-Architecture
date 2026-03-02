# 🛡️ Audit Logs & Common Ops Capability

## Core Domain
**Platform & Operations**

## Overview
Ecosystem for auditing user actions (especially Admin/Manager) and providing shared system utilities (file upload, data export, task orchestration).

## Key Capabilities
1. **Admin Action Audit:** Detailed logging of who (User), did what (Action), when (Time), on what resource (Resource), and the diff (Old/New values).
2. **File Processing:** Upload/Download documents, bills, high-resolution images.
3. **Background Tasks:** Management of heavy tasks such as bulk export of Excel/CSV reports.
4. **Config Management:** Centralized settings for global platform behaviors.

## Integrations
- Called by almost all internal services (via gRPC/HTTP requests to the `Common Ops` service).
