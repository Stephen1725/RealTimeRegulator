💡 RealTimeRegulator
====================

📜 Contract: `Real-Time Regulatory Compliance Checker`
------------------------------------------------------

This smart contract, written in **Clarity**, establishes a decentralized, transparent, and immutable system for tracking and verifying the regulatory compliance status of various entities. It supports multiple compliance frameworks, automated risk assessments, and maintains a comprehensive audit trail and violation history. The contract is designed to bring real-time compliance verification to decentralized applications (dApps) and institutional DeFi (Decentralized Finance).

* * * * *

🚀 Features
-----------

-   **Decentralized Access Control:** Only designated **Compliance Officers** can update entity status, with the contract **owner** managing the officer list.

-   **Multiple Frameworks:** Supports registration and tracking of compliance against various regulatory standards (e.g., KYC, AML, industry-specific standards).

-   **Real-Time Status:** Provides functions for checking compliance status and expiration in real-time based on the current `block-height`.

-   **Comprehensive Verification:** The `verify-comprehensive-compliance` function performs a multi-factor check, validating score, expiration, status, framework requirements, and risk level.

-   **Immutable Audit Trail:** All status updates are permanently logged in the `compliance-audit-trail`.

-   **Automated Risk Assessment:** Calculates an entity's **risk-level** (Low, Medium, High) based on their **compliance-score**.

-   **Violation Management:** Records and tracks violations, with an option for automatic status update to **Non-Compliant** for high-severity violations.

* * * * *

🛠️ Data Structures
-------------------

### 1\. Variables

| Variable | Type | Description | Initial Value |
| --- | --- | --- | --- |
| `audit-counter` | `uint` | Counter for generating unique audit trail `check-id`s. | `u0` |
| `violation-counter` | `uint` | Counter for generating unique violation `violation-id`s. | `u0` |

### 2\. Maps

| Map Name | Key Type | Value Type (Tuple) | Description |
| --- | --- | --- | --- |
| `compliance-officers` | `principal` | `bool` | Tracks authorized principals who can perform compliance updates. |
| `entity-compliance` | `principal` | `{status: uint, compliance-score: uint, last-check-date: uint, expiry-date: uint, framework-id: (string-ascii 50), risk-level: uint, verified-by: principal}` | Stores the main compliance record for each entity. |
| `compliance-frameworks` | `(string-ascii 50)` | `{name: (string-ascii 100), min-score: uint, validity-period: uint, active: bool, created-at: uint}` | Defines requirements and parameters for each compliance standard. |
| `compliance-audit-trail` | `{entity: principal, check-id: uint}` | `{timestamp: uint, previous-status: uint, new-status: uint, compliance-score: uint, notes: (string-ascii 200), officer: principal}` | Immutable log of all compliance status changes. |
| `violation-history` | `{entity: principal, violation-id: uint}` | `{violation-type: (string-ascii 100), severity: uint, timestamp: uint, resolved: bool, resolution-date: (optional uint)}` | Records compliance infractions for entities. |

### 3\. Constants and Errors

| Constant | Type | Value | Description |
| --- | --- | --- | --- |
| `contract-owner` | `principal` | `tx-sender` | The address that deployed the contract. |
| `status-compliant` | `uint` | `u1` | Entity meets compliance requirements. |
| `status-non-compliant` | `uint` | `u2` | Entity fails compliance requirements. |
| `status-pending-review` | `uint` | `u3` | Compliance status requires manual check. |
| `status-suspended` | `uint` | `u4` | Compliance status has been temporarily revoked. |
| `err-owner-only` | `(err u100)` | `u100` | Operation restricted to the contract owner. |
| `err-not-found` | `(err u101)` | `u101` | Requested record or entity was not found. |
| `err-unauthorized` | `(err u103)` | `u103` | Sender is not an authorized compliance officer. |
| `err-invalid-status` | `(err u104)` | `u104` | The provided status code or severity is invalid. |
| `err-invalid-score` | `(err u106)` | `u106` | Compliance score is outside the valid range (0-100). |

* * * * *

⚙️ Public Functions (Entrypoints)
---------------------------------

### **1\. Initialization & Officer Management**

| Function | Arguments | Description |
| --- | --- | --- |
| `(initialize)` | `()` | **(Owner-only)** Sets the contract deployer as the first `compliance-officer`. **Required** before any compliance updates. |
| `(add-compliance-officer (officer principal))` | `officer`: `principal` | **(Owner-only)** Grants update privileges to a new principal. |
| `(remove-compliance-officer (officer principal))` | `officer`: `principal` | **(Owner-only)** Revokes update privileges from an existing principal. |

### **2\. Framework Management**

| Function | Arguments | Description |
| --- | --- | --- |
| `(register-framework ...)` | `framework-id`: `(string-ascii 50)`, `name`: `(string-ascii 100)`, `min-score`: `uint`, `validity-period`: `uint` | **(Owner-only)** Registers a new compliance standard, including the minimum required score and the validity period (in block height units). |

### **3\. Entity Compliance**

| Function | Arguments | Description |
| --- | --- | --- |
| `(update-entity-compliance ...)` | `entity`: `principal`, `status`: `uint`, `compliance-score`: `uint`, `framework-id`: `(string-ascii 50)`, `validity-period`: `uint` | **(Officer-only)** Registers a new compliance record or updates an existing one. Automatically creates an entry in the `compliance-audit-trail` and calculates the new **risk-level**. |
| `(record-violation ...)` | `entity`: `principal`, `violation-type`: `(string-ascii 100)`, `severity`: `uint` | **(Officer-only)** Records an infraction. Severity ranges from `u1` (low) to `u5` (critical). **Automatically updates entity status to `status-non-compliant` if severity is ≥ `u4`**. |

* * * * *

🔍 Read-Only Functions
----------------------

| Function | Arguments | Returns | Description |
| --- | --- | --- | --- |
| `(is-entity-compliant (entity principal))` | `entity`: `principal` | `bool` | Returns `true` only if the entity's status is **Compliant (u1)** AND their record is **not expired**. |
| `(get-entity-compliance (entity principal))` | `entity`: `principal` | `(response (optional {..}) (err none))` | Retrieves the full compliance record for an entity. |
| `(get-framework (framework-id (string-ascii 50)))` | `framework-id`: `(string-ascii 50)` | `(response (optional {..}) (err none))` | Retrieves the details of a registered compliance framework. |
| `(is-compliance-officer (officer principal))` | `officer`: `principal` | `bool` | Checks if a principal is an authorized compliance officer. |
| `(verify-comprehensive-compliance ...)` | `entity`: `principal`, `framework-id`: `(string-ascii 50)`, `required-min-score`: `uint` | `(response {..} (err u103|u101))` | **(Officer-only)** Performs an in-depth, multi-factor verification check against specified criteria and the entity's stored record. Returns a detailed tuple of all checks passed/failed. |

* * * * *

🔒 Private Functions (Internal Logic)
-------------------------------------

| Function | Arguments | Description |
| --- | --- | --- |
| `(is-valid-score (score uint))` | `score`: `uint` | Checks if the compliance score is within the valid range: u0≤score≤u100. |
| `(is-valid-status (status uint))` | `status`: `uint` | Checks if the provided status code is one of the four defined constants. |
| `(is-expired (expiry-date uint))` | `expiry-date`: `uint` | Returns `true` if `block-height` is greater than `expiry-date`. |
| `(calculate-risk-level (score uint))` | `score`: `uint` | Assigns a risk level based on the score: **Low** (u1) for score ≥u80, **Medium** (u2) for u50≤score<u80, and **High** (u3) for score <u50. |

* * * * *

🔄 Core Logic: Comprehensive Verification Flow
----------------------------------------------

The `verify-comprehensive-compliance` function is the most robust compliance check in the contract. It performs the following checks in sequence:

1.  **Authorization Check:** Verify `tx-sender` is a **Compliance Officer** (err-unauthorized).

2.  **Record Existence Check:** Verify both `entity-compliance` and `compliance-frameworks` records exist (err-not-found).

3.  **Required Score Check:** Is `entity.compliance-score` ≥ `required-min-score`?

4.  **Framework Score Check:** Is `entity.compliance-score` ≥ `framework.min-score`?

5.  **Expiration Check:** Is `block-height` ≤ `entity.expiry-date`?

6.  **Status Check:** Is `entity.status` u1 (**Compliant**)?

7.  **Framework Match Check:** Does `entity.framework-id` match the requested `framework-id`?

8.  **Risk Check:** Is `entity.risk-level` acceptable (≤u2)?

The function returns a detailed tuple indicating the pass/fail status of each individual check, culminating in a single `compliant: bool` result.

* * * * *

🤝 Contribution
---------------

This contract is open-source and contributions are welcome. For bug reports, feature requests, or security issues, please open an issue on the relevant GitHub repository. Before submitting a pull request, please ensure your code adheres to the following guidelines:

1.  **Clarity Language Standard:** All code must be written in the Clarity programming language and adhere to its conventions.

2.  **Testing:** All new features or bug fixes must be accompanied by comprehensive unit tests covering happy paths and error conditions.

3.  **Security Focus:** Prioritize immutability, access control (using `tx-sender` and `asserts!`), and secure handling of data inputs.

4.  **Documentation:** Comment all public and private functions, variables, and constants.

* * * * *

📝 MIT License
--------------

Copyright (c) 2025 RealTimeRegulator

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

**THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.**
