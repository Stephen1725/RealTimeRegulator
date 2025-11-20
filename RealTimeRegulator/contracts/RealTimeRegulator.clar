;; Real-Time Regulatory Compliance Checker
;; This smart contract provides a decentralized system for tracking and verifying
;; regulatory compliance status of entities in real-time. It supports multiple
;; compliance frameworks, automated checks, and maintains an immutable audit trail.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-status (err u104))
(define-constant err-expired (err u105))
(define-constant err-invalid-score (err u106))

;; Compliance status codes
(define-constant status-compliant u1)
(define-constant status-non-compliant u2)
(define-constant status-pending-review u3)
(define-constant status-suspended u4)

;; data maps and vars
;; Tracks registered compliance officers who can update compliance status
(define-map compliance-officers principal bool)

;; Stores entity compliance records with detailed information
(define-map entity-compliance
    principal
    {
        status: uint,
        compliance-score: uint,
        last-check-date: uint,
        expiry-date: uint,
        framework-id: (string-ascii 50),
        risk-level: uint,
        verified-by: principal
    }
)

;; Tracks compliance frameworks and their requirements
(define-map compliance-frameworks
    (string-ascii 50)
    {
        name: (string-ascii 100),
        min-score: uint,
        validity-period: uint,
        active: bool,
        created-at: uint
    }
)

;; Audit trail for all compliance checks
(define-map compliance-audit-trail
    {entity: principal, check-id: uint}
    {
        timestamp: uint,
        previous-status: uint,
        new-status: uint,
        compliance-score: uint,
        notes: (string-ascii 200),
        officer: principal
    }
)

;; Counter for audit trail entries
(define-data-var audit-counter uint u0)

;; Tracks violation history for entities
(define-map violation-history
    {entity: principal, violation-id: uint}
    {
        violation-type: (string-ascii 100),
        severity: uint,
        timestamp: uint,
        resolved: bool,
        resolution-date: (optional uint)
    }
)

;; Counter for violations
(define-data-var violation-counter uint u0)

;; private functions
;; Validates if a compliance score is within acceptable range (0-100)
(define-private (is-valid-score (score uint))
    (and (>= score u0) (<= score u100))
)

;; Checks if a compliance status is valid
(define-private (is-valid-status (status uint))
    (or (is-eq status status-compliant)
        (or (is-eq status status-non-compliant)
            (or (is-eq status status-pending-review)
                (is-eq status status-suspended))))
)

;; Calculates if compliance has expired based on current block height
(define-private (is-expired (expiry-date uint))
    (> block-height expiry-date)
)

;; Determines risk level based on compliance score (1=low, 2=medium, 3=high)
(define-private (calculate-risk-level (score uint))
    (if (>= score u80)
        u1
        (if (>= score u50)
            u2
            u3))
)

;; public functions
;; Initialize the contract owner as the first compliance officer
(define-public (initialize)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set compliance-officers contract-owner true))
    )
)

;; Add a new compliance officer (only owner can do this)
(define-public (add-compliance-officer (officer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set compliance-officers officer true))
    )
)

;; Remove a compliance officer
(define-public (remove-compliance-officer (officer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-delete compliance-officers officer))
    )
)

;; Register a new compliance framework
(define-public (register-framework 
    (framework-id (string-ascii 50))
    (name (string-ascii 100))
    (min-score uint)
    (validity-period uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-valid-score min-score) err-invalid-score)
        (ok (map-set compliance-frameworks framework-id
            {
                name: name,
                min-score: min-score,
                validity-period: validity-period,
                active: true,
                created-at: block-height
            }))
    )
)

;; Register or update entity compliance status
(define-public (update-entity-compliance
    (entity principal)
    (status uint)
    (compliance-score uint)
    (framework-id (string-ascii 50))
    (validity-period uint))
    (let
        (
            (officer-authorized (default-to false (map-get? compliance-officers tx-sender)))
            (current-record (map-get? entity-compliance entity))
            (expiry-date (+ block-height validity-period))
            (risk-level (calculate-risk-level compliance-score))
            (current-audit-id (var-get audit-counter))
        )
        (asserts! officer-authorized err-unauthorized)
        (asserts! (is-valid-status status) err-invalid-status)
        (asserts! (is-valid-score compliance-score) err-invalid-score)
        
        ;; Create audit trail entry
        (map-set compliance-audit-trail
            {entity: entity, check-id: current-audit-id}
            {
                timestamp: block-height,
                previous-status: (default-to u0 (get status current-record)),
                new-status: status,
                compliance-score: compliance-score,
                notes: "Compliance status updated",
                officer: tx-sender
            })
        
        ;; Update audit counter
        (var-set audit-counter (+ current-audit-id u1))
        
        ;; Update entity compliance record
        (ok (map-set entity-compliance entity
            {
                status: status,
                compliance-score: compliance-score,
                last-check-date: block-height,
                expiry-date: expiry-date,
                framework-id: framework-id,
                risk-level: risk-level,
                verified-by: tx-sender
            }))
    )
)

;; Check if an entity is currently compliant
(define-read-only (is-entity-compliant (entity principal))
    (let
        (
            (record (map-get? entity-compliance entity))
        )
        (match record
            compliance-data
                (and 
                    (is-eq (get status compliance-data) status-compliant)
                    (not (is-expired (get expiry-date compliance-data))))
            false
        )
    )
)

;; Get entity compliance details
(define-read-only (get-entity-compliance (entity principal))
    (ok (map-get? entity-compliance entity))
)

;; Get compliance framework details
(define-read-only (get-framework (framework-id (string-ascii 50)))
    (ok (map-get? compliance-frameworks framework-id))
)

;; Check if a principal is a compliance officer
(define-read-only (is-compliance-officer (officer principal))
    (default-to false (map-get? compliance-officers officer))
)

;; Record a compliance violation for an entity
(define-public (record-violation
    (entity principal)
    (violation-type (string-ascii 100))
    (severity uint))
    (let
        (
            (officer-authorized (default-to false (map-get? compliance-officers tx-sender)))
            (current-violation-id (var-get violation-counter))
        )
        (asserts! officer-authorized err-unauthorized)
        (asserts! (and (>= severity u1) (<= severity u5)) err-invalid-status)
        
        ;; Record the violation
        (map-set violation-history
            {entity: entity, violation-id: current-violation-id}
            {
                violation-type: violation-type,
                severity: severity,
                timestamp: block-height,
                resolved: false,
                resolution-date: none
            })
        
        ;; Increment violation counter
        (var-set violation-counter (+ current-violation-id u1))
        
        ;; Automatically update entity status to non-compliant if severity is high
        (if (>= severity u4)
            (update-entity-compliance entity status-non-compliant u0 "VIOLATION" u0)
            (ok true))
    )
)


