;; Smart Contract Auditing Marketplace
;; A comprehensive platform connecting security auditors with projects needing code reviews

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-audit-not-available (err u105))
(define-constant err-audit-already-assigned (err u106))
(define-constant err-audit-not-assigned (err u107))
(define-constant err-audit-already-completed (err u108))
(define-constant err-invalid-score (err u109))
(define-constant err-deadline-passed (err u110))
(define-constant err-not-auditor (err u111))

;; Data Variables
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points
(define-data-var min-certification-score uint u75)
(define-data-var next-auditor-id uint u1)
(define-data-var next-project-id uint u1)
(define-data-var next-audit-id uint u1)

;; Certification Levels
(define-constant cert-none u0)
(define-constant cert-basic u1)
(define-constant cert-professional u2)
(define-constant cert-expert u3)

;; Vulnerability Severity Levels (standardized scoring)
(define-constant severity-info u1)
(define-constant severity-low u2)
(define-constant severity-medium u3)
(define-constant severity-high u4)
(define-constant severity-critical u5)

;; Audit Status
(define-constant status-open u1)
(define-constant status-assigned u2)
(define-constant status-in-progress u3)
(define-constant status-completed u4)
(define-constant status-disputed u5)

;; Data Maps

;; Auditor profiles with certification and reputation
(define-map auditors
  { auditor-id: uint }
  {
    owner: principal,
    certification-level: uint,
    total-audits: uint,
    successful-audits: uint,
    average-rating: uint,
    specializations: (list 5 (string-ascii 20)),
    hourly-rate: uint,
    is-active: bool,
    certification-expires: uint,
    reputation-score: uint
  }
)

;; Principal to auditor ID mapping
(define-map principal-to-auditor principal uint)

;; Project audit requests
(define-map projects
  { project-id: uint }
  {
    owner: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    code-repository: (string-ascii 200),
    budget: uint,
    deadline: uint,
    required-certification: uint,
    specialization-required: (string-ascii 20),
    status: uint,
    assigned-auditor: (optional uint),
    escrow-amount: uint,
    created-at: uint
  }
)

;; Audit assignments and results
(define-map audits
  { audit-id: uint }
  {
    project-id: uint,
    auditor-id: uint,
    start-block: uint,
    completion-block: (optional uint),
    total-vulnerabilities: uint,
    critical-count: uint,
    high-count: uint,
    medium-count: uint,
    low-count: uint,
    info-count: uint,
    overall-score: uint,
    report-hash: (string-ascii 64),
    client-rating: (optional uint),
    is-disputed: bool,
    payment-released: bool
  }
)

;; Vulnerability findings for detailed tracking
(define-map vulnerabilities
  { audit-id: uint, vulnerability-index: uint }
  {
    severity: uint,
    category: (string-ascii 50),
    description: (string-ascii 300),
    remediation: (string-ascii 200),
    line-number: (optional uint),
    is-fixed: bool
  }
)

;; Escrow holdings
(define-map escrow
  { project-id: uint }
  { amount: uint, locked: bool }
)

;; Certification requirements and standards
(define-map certification-requirements
  { level: uint }
  {
    min-audits: uint,
    min-success-rate: uint,
    min-reputation: uint,
    expires-after-blocks: uint,
    certification-fee: uint
  }
)

;; Helper Functions

;; Calculate reputation score based on performance metrics
(define-private (calculate-reputation-score (total-audits uint) (successful-audits uint) (avg-rating uint))
  (let (
    (success-rate (if (> total-audits u0) (/ (* successful-audits u100) total-audits) u0))
    (base-score (* success-rate avg-rating))
  )
    (if (> total-audits u10)
      (+ base-score u10) ;; Bonus for experience
      base-score
    )
  )
)

;; Calculate overall audit score based on vulnerability counts
(define-private (calculate-audit-score (critical uint) (high uint) (medium uint) (low uint) (info uint))
  (let (
    (total-weight (+ (* critical u100) (* high u50) (* medium u25) (* low u10) (* info u5)))
    (max-possible u1000) ;; Theoretical maximum for normalization
  )
    (if (> total-weight max-possible)
      u0 ;; Very poor security
      (- u100 (/ (* total-weight u100) max-possible))
    )
  )
)

;; Verify auditor certification is current
(define-private (is-certification-current (auditor-id uint))
  (match (map-get? auditors { auditor-id: auditor-id })
    auditor-data (> (get certification-expires auditor-data) stacks-block-height)
    false
  )
)

;; Public Functions

;; Initialize certification standards
(define-public (initialize-certification-standards)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)

    ;; Basic certification
    (map-set certification-requirements { level: cert-basic }
      {
        min-audits: u5,
        min-success-rate: u80,
        min-reputation: u60,
        expires-after-blocks: u52560, ;; ~1 year
        certification-fee: u1000000 ;; 1 STX
      }
    )

    ;; Professional certification
    (map-set certification-requirements { level: cert-professional }
      {
        min-audits: u15,
        min-success-rate: u85,
        min-reputation: u75,
        expires-after-blocks: u52560,
        certification-fee: u2500000 ;; 2.5 STX
      }
    )

    ;; Expert certification
    (map-set certification-requirements { level: cert-expert }
      {
        min-audits: u50,
        min-success-rate: u90,
        min-reputation: u85,
        expires-after-blocks: u52560,
        certification-fee: u5000000 ;; 5 STX
      }
    )

    (ok true)
  )
)

;; Register new auditor
(define-public (register-auditor
  (specializations (list 5 (string-ascii 20)))
  (hourly-rate uint))
  (let (
    (auditor-id (var-get next-auditor-id))
  )
    (asserts! (is-none (map-get? principal-to-auditor tx-sender)) err-unauthorized)
    (asserts! (and (>= (len specializations) u1) (<= (len specializations) u5)) err-invalid-params)
    (asserts! (> hourly-rate u0) err-invalid-params)

    (map-set auditors { auditor-id: auditor-id }
      {
        owner: tx-sender,
        certification-level: cert-none,
        total-audits: u0,
        successful-audits: u0,
        average-rating: u0,
        specializations: specializations,
        hourly-rate: hourly-rate,
        is-active: true,
        certification-expires: u0,
        reputation-score: u0
      }
    )

    (map-set principal-to-auditor tx-sender auditor-id)
    (var-set next-auditor-id (+ auditor-id u1))

    (ok auditor-id)
  )
)

;; Apply for certification upgrade
(define-public (apply-for-certification (target-level uint))
  (let (
    (auditor-id-opt (map-get? principal-to-auditor tx-sender))
    (auditor-id (unwrap! auditor-id-opt err-not-auditor))
    (auditor-data (unwrap! (map-get? auditors { auditor-id: auditor-id }) err-not-found))
    (cert-req (unwrap! (map-get? certification-requirements { level: target-level }) err-invalid-params))
  )
    (asserts! (and (>= target-level cert-basic) (<= target-level cert-expert)) err-invalid-params)
    (asserts! (> target-level (get certification-level auditor-data)) err-invalid-params)

    ;; Check requirements
    (asserts! (>= (get total-audits auditor-data) (get min-audits cert-req)) err-invalid-params)
    (asserts! (>= (/ (* (get successful-audits auditor-data) u100) (get total-audits auditor-data)) (get min-success-rate cert-req)) err-invalid-params)
    (asserts! (>= (get reputation-score auditor-data) (get min-reputation cert-req)) err-invalid-params)

    ;; Pay certification fee
    (try! (stx-transfer? (get certification-fee cert-req) tx-sender contract-owner))

    ;; Update certification
    (map-set auditors { auditor-id: auditor-id }
      (merge auditor-data {
        certification-level: target-level,
        certification-expires: (+ stacks-block-height (get expires-after-blocks cert-req))
      })
    )

    (ok true)
  )
)

;; Submit project for audit
(define-public (submit-project
  (title (string-ascii 100))
  (description (string-ascii 500))
  (code-repository (string-ascii 200))
  (budget uint)
  (deadline-blocks uint)
  (required-certification uint)
  (specialization-required (string-ascii 20)))
  (let (
    (project-id (var-get next-project-id))
    (deadline (+ stacks-block-height deadline-blocks))
  )
    (asserts! (and (> (len title) u0) (<= (len title) u100)) err-invalid-params)
    (asserts! (> budget u100000) err-invalid-params) ;; Minimum 0.1 STX
    (asserts! (> deadline-blocks u144) err-invalid-params) ;; At least 1 day
    (asserts! (<= required-certification cert-expert) err-invalid-params)

    ;; Transfer budget to escrow
    (try! (stx-transfer? budget tx-sender (as-contract tx-sender)))

    (map-set projects { project-id: project-id }
      {
        owner: tx-sender,
        title: title,
        description: description,
        code-repository: code-repository,
        budget: budget,
        deadline: deadline,
        required-certification: required-certification,
        specialization-required: specialization-required,
        status: status-open,
        assigned-auditor: none,
        escrow-amount: budget,
        created-at: stacks-block-height
      }
    )

    (map-set escrow { project-id: project-id }
      { amount: budget, locked: true }
    )

    (var-set next-project-id (+ project-id u1))

    (ok project-id)
  )
)

;; Auditor accepts audit assignment
(define-public (accept-audit (project-id uint))
  (let (
    (auditor-id-opt (map-get? principal-to-auditor tx-sender))
    (auditor-id (unwrap! auditor-id-opt err-not-auditor))
    (auditor-data (unwrap! (map-get? auditors { auditor-id: auditor-id }) err-not-found))
    (project-data (unwrap! (map-get? projects { project-id: project-id }) err-not-found))
    (audit-id (var-get next-audit-id))
  )
    (asserts! (is-eq (get status project-data) status-open) err-audit-not-available)
    (asserts! (get is-active auditor-data) err-unauthorized)
    (asserts! (>= (get certification-level auditor-data) (get required-certification project-data)) err-unauthorized)
    (asserts! (< stacks-block-height (get deadline project-data)) err-deadline-passed)

    ;; Check if specialization matches (if required)
    (if (> (len (get specialization-required project-data)) u0)
      (asserts!
        (is-some (index-of (get specializations auditor-data) (get specialization-required project-data)))
        err-unauthorized
      )
      true
    )

    ;; Check certification is current
    (asserts! (is-certification-current auditor-id) err-unauthorized)

    ;; Update project status
    (map-set projects { project-id: project-id }
      (merge project-data {
        status: status-assigned,
        assigned-auditor: (some auditor-id)
      })
    )

    ;; Create audit record
    (map-set audits { audit-id: audit-id }
      {
        project-id: project-id,
        auditor-id: auditor-id,
        start-block: stacks-block-height,
        completion-block: none,
        total-vulnerabilities: u0,
        critical-count: u0,
        high-count: u0,
        medium-count: u0,
        low-count: u0,
        info-count: u0,
        overall-score: u0,
        report-hash: "",
        client-rating: none,
        is-disputed: false,
        payment-released: false
      }
    )

    (var-set next-audit-id (+ audit-id u1))

    (ok audit-id)
  )
)

;; Submit audit results
(define-public (submit-audit-results
  (audit-id uint)
  (vulnerabilities-data (list 20 { severity: uint, category: (string-ascii 50), description: (string-ascii 300), remediation: (string-ascii 200), line-number: (optional uint) }))
  (report-hash (string-ascii 64)))
  (let (
    (auditor-id-opt (map-get? principal-to-auditor tx-sender))
    (auditor-id (unwrap! auditor-id-opt err-not-auditor))
    (audit-data (unwrap! (map-get? audits { audit-id: audit-id }) err-not-found))
    (project-data (unwrap! (map-get? projects { project-id: (get project-id audit-data) }) err-not-found))
  )
    (asserts! (is-eq (get auditor-id audit-data) auditor-id) err-unauthorized)
    (asserts! (is-none (get completion-block audit-data)) err-audit-already-completed)
    (asserts! (< stacks-block-height (get deadline project-data)) err-deadline-passed)
    (asserts! (> (len report-hash) u0) err-invalid-params)

    ;; Process vulnerabilities and count by severity
    (let (
      (processed-counts (fold process-vulnerability vulnerabilities-data
        { critical: u0, high: u0, medium: u0, low: u0, info: u0, index: u0 }))
      (total-vulns (+ (get critical processed-counts) (get high processed-counts)
                     (get medium processed-counts) (get low processed-counts) (get info processed-counts)))
      (overall-score (calculate-audit-score
        (get critical processed-counts) (get high processed-counts)
        (get medium processed-counts) (get low processed-counts) (get info processed-counts)))
    )
      ;; Store vulnerabilities
      (map store-vulnerability-helper
        (map add-audit-id-to-vuln vulnerabilities-data)
        (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19))

      ;; Update audit record
      (map-set audits { audit-id: audit-id }
        (merge audit-data {
          completion-block: (some stacks-block-height),
          total-vulnerabilities: total-vulns,
          critical-count: (get critical processed-counts),
          high-count: (get high processed-counts),
          medium-count: (get medium processed-counts),
          low-count: (get low processed-counts),
          info-count: (get info processed-counts),
          overall-score: overall-score,
          report-hash: report-hash
        })
      )

      ;; Update project status
      (map-set projects { project-id: (get project-id audit-data) }
        (merge project-data { status: status-completed })
      )

      (ok overall-score)
    )
  )
)

;; Helper function to process vulnerabilities
(define-private (process-vulnerability
  (vuln { severity: uint, category: (string-ascii 50), description: (string-ascii 300), remediation: (string-ascii 200), line-number: (optional uint) })
  (acc { critical: uint, high: uint, medium: uint, low: uint, info: uint, index: uint }))
  (let (
    (severity (get severity vuln))
    (new-index (+ (get index acc) u1))
  )
    (merge acc {
      critical: (if (is-eq severity severity-critical) (+ (get critical acc) u1) (get critical acc)),
      high: (if (is-eq severity severity-high) (+ (get high acc) u1) (get high acc)),
      medium: (if (is-eq severity severity-medium) (+ (get medium acc) u1) (get medium acc)),
      low: (if (is-eq severity severity-low) (+ (get low acc) u1) (get low acc)),
      info: (if (is-eq severity severity-info) (+ (get info acc) u1) (get info acc)),
      index: new-index
    })
  )
)

;; Helper to add audit-id to vulnerability data
(define-private (add-audit-id-to-vuln (vuln { severity: uint, category: (string-ascii 50), description: (string-ascii 300), remediation: (string-ascii 200), line-number: (optional uint) }))
  vuln ;; In a real implementation, this would add the audit-id
)

;; Helper to store individual vulnerabilities
(define-private (store-vulnerability-helper
  (vuln { severity: uint, category: (string-ascii 50), description: (string-ascii 300), remediation: (string-ascii 200), line-number: (optional uint) })
  (index uint))
  (map-set vulnerabilities { audit-id: (var-get next-audit-id), vulnerability-index: index }
    {
      severity: (get severity vuln),
      category: (get category vuln),
      description: (get description vuln),
      remediation: (get remediation vuln),
      line-number: (get line-number vuln),
      is-fixed: false
    }
  )
)

;; Client rates auditor and releases payment
(define-public (rate-and-pay (audit-id uint) (rating uint))
  (let (
    (audit-data (unwrap! (map-get? audits { audit-id: audit-id }) err-not-found))
    (project-data (unwrap! (map-get? projects { project-id: (get project-id audit-data) }) err-not-found))
    (auditor-data (unwrap! (map-get? auditors { auditor-id: (get auditor-id audit-data) }) err-not-found))
    (escrow-data (unwrap! (map-get? escrow { project-id: (get project-id audit-data) }) err-not-found))
    (platform-fee (/ (* (get amount escrow-data) (var-get platform-fee-rate)) u10000))
    (auditor-payment (- (get amount escrow-data) platform-fee))
  )
    (asserts! (is-eq tx-sender (get owner project-data)) err-unauthorized)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-score)
    (asserts! (is-some (get completion-block audit-data)) err-audit-not-assigned)
    (asserts! (not (get payment-released audit-data)) err-audit-already-completed)
    (asserts! (get locked escrow-data) err-insufficient-funds)

    ;; Update audit with rating
    (map-set audits { audit-id: audit-id }
      (merge audit-data {
        client-rating: (some rating),
        payment-released: true
      })
    )

    ;; Release payment
    (try! (as-contract (stx-transfer? auditor-payment tx-sender (get owner auditor-data))))
    (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))

    ;; Update escrow
    (map-set escrow { project-id: (get project-id audit-data) }
      { amount: u0, locked: false }
    )

    ;; Update auditor stats
    (let (
      (new-total (+ (get total-audits auditor-data) u1))
      (new-successful (+ (get successful-audits auditor-data) u1))
      (new-avg-rating (/ (+ (* (get average-rating auditor-data) (get total-audits auditor-data)) rating) new-total))
      (new-reputation (calculate-reputation-score new-total new-successful new-avg-rating))
    )
      (map-set auditors { auditor-id: (get auditor-id audit-data) }
        (merge auditor-data {
          total-audits: new-total,
          successful-audits: new-successful,
          average-rating: new-avg-rating,
          reputation-score: new-reputation
        })
      )
    )

    (ok auditor-payment)
  )
)

;; Read-only functions for querying data

(define-read-only (get-auditor (auditor-id uint))
  (map-get? auditors { auditor-id: auditor-id })
)

(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

(define-read-only (get-audit (audit-id uint))
  (map-get? audits { audit-id: audit-id })
)

(define-read-only (get-auditor-by-principal (principal principal))
  (match (map-get? principal-to-auditor principal)
    auditor-id (map-get? auditors { auditor-id: auditor-id })
    none
  )
)

(define-read-only (get-vulnerability (audit-id uint) (vuln-index uint))
  (map-get? vulnerabilities { audit-id: audit-id, vulnerability-index: vuln-index })
)

(define-read-only (get-certification-requirements (level uint))
  (map-get? certification-requirements { level: level })
)

(define-read-only (get-platform-stats)
  {
    total-auditors: (- (var-get next-auditor-id) u1),
    total-projects: (- (var-get next-project-id) u1),
    total-audits: (- (var-get next-audit-id) u1),
    platform-fee-rate: (var-get platform-fee-rate)
  }
)
