
;; Title: STX-CollaatX
;; Synthetic Asset Smart Contract

;; Error code
(define-constant ERROR-NOT-AUTHORIZED (err u100))
(define-constant ERROR-TOKEN-BALANCE-TOO-LOW (err u101))
(define-constant ERROR-INVALID-TOKEN-QUANTITY (err u102))
(define-constant ERROR-ORACLE-DATA-STALE (err u103))
(define-constant ERROR-COLLATERAL-DEPOSIT-INSUFFICIENT (err u104))
(define-constant ERROR-COLLATERAL-BELOW-THRESHOLD (err u105))
(define-constant ERROR-PRICE-OUT-OF-BOUNDS (err u106))
(define-constant ERROR-CALCULATION-OVERFLOW (err u107))
(define-constant ERROR-INVALID-TRANSFER-RECIPIENT (err u108))
(define-constant ERROR-AMOUNT-MUST-BE-POSITIVE (err u109))
(define-constant ERROR-VAULT-NOT-FOUND (err u110))

;; System constants
(define-constant SYSTEM-ADMIN tx-sender)
(define-constant PRICE-VALIDITY-PERIOD-BLOCKS u900) ;; 15 minutes in blocks
(define-constant COLLATERAL-SAFETY-RATIO u150) ;; 150%
(define-constant COLLATERAL-LIQUIDATION-RATIO u120) ;; 120%
(define-constant MIN-TOKEN-ISSUANCE-AMOUNT u100000000) ;; 1.00 tokens (8 decimals)
(define-constant MAX-ALLOWED-PRICE u1000000000000) ;; Price ceiling for safety
(define-constant UINT_MAX u340282366920938463463374607431768211455) ;; 2^128 - 1

;; System state variables
(define-data-var oracle-update-block-height uint u0)
(define-data-var current-market-price uint u0)
(define-data-var global-token-supply uint u0)

;; Data storage structures
(define-map user-token-holdings principal uint)
(define-map collateralized-positions
    principal
    {
        staked-collateral: uint,
        issued-synthetic-tokens: uint,
        position-open-price: uint
    }
)


;;;; Private Function
;; Internal helper functions
(define-private (process-token-transfer (sender principal) (receiver principal) (transfer-amount uint))
    (let (
        (sender-current-balance (get-user-token-balance sender))
    )
    ;; Safety checks
    (asserts! (> transfer-amount u0) ERROR-AMOUNT-MUST-BE-POSITIVE)
    (asserts! (not (is-eq sender receiver)) ERROR-INVALID-TRANSFER-RECIPIENT)
    (asserts! (>= sender-current-balance transfer-amount) ERROR-TOKEN-BALANCE-TOO-LOW)
    (asserts! (is-some (map-get? user-token-holdings sender)) ERROR-NOT-AUTHORIZED)

    (match (secure-add (get-user-token-balance receiver) transfer-amount)
        receiver-new-balance
            (match (secure-subtract sender-current-balance transfer-amount)
                sender-new-balance
                    (begin
                        (map-set user-token-holdings sender sender-new-balance)
                        (map-set user-token-holdings receiver receiver-new-balance)
                        (ok true))
                error ERROR-CALCULATION-OVERFLOW)
        error ERROR-CALCULATION-OVERFLOW))
)


;; Protected arithmetic operations
(define-private (secure-multiply (value-a uint) (value-b uint))
    (let ((product-result (* value-a value-b)))
        (asserts! (or (is-eq value-a u0) (is-eq (/ product-result value-a) value-b)) ERROR-CALCULATION-OVERFLOW)
        (ok product-result)))

(define-private (secure-add (value-a uint) (value-b uint))
    (let ((sum-result (+ value-a value-b)))
        (asserts! (>= sum-result value-a) ERROR-CALCULATION-OVERFLOW)
        (ok sum-result)))

(define-private (secure-subtract (value-a uint) (value-b uint))
    (begin
        (asserts! (>= value-a value-b) ERROR-CALCULATION-OVERFLOW)
        (ok (- value-a value-b))))

;; Query functions
(define-read-only (get-user-token-balance (account-holder principal))
    (default-to u0 (map-get? user-token-holdings account-holder))
)

(define-read-only (get-circulating-supply)
    (var-get global-token-supply)
)

(define-read-only (get-market-price)
    (var-get current-market-price)
)

(define-read-only (get-position-details (position-owner principal))
    (map-get? collateralized-positions position-owner)
)

(define-read-only (calculate-position-health-ratio (position-owner principal))
    (let (
        (position-data (unwrap! (get-position-details position-owner) (err u0)))
        (latest-price (var-get current-market-price))
    )
    (if (> (get issued-synthetic-tokens position-data) u0)
        (match (secure-multiply (get staked-collateral position-data) u100)
            collateral-value-base (match (secure-multiply collateral-value-base u100)
                collateral-value-adjusted (match (secure-multiply (get issued-synthetic-tokens position-data) latest-price)
                    synthetic-value (ok (/ collateral-value-adjusted synthetic-value))
                    error ERROR-CALCULATION-OVERFLOW)
                error ERROR-CALCULATION-OVERFLOW)
            error ERROR-CALCULATION-OVERFLOW)
        (err u0)))
)


;;; PUBLIC FUNCTIONS ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; External functions
(define-public (set-price-feed-value (new-price uint))
    (begin
        (asserts! (is-eq tx-sender SYSTEM-ADMIN) ERROR-NOT-AUTHORIZED)
        (asserts! (> new-price u0) ERROR-PRICE-OUT-OF-BOUNDS)
        (asserts! (< new-price MAX-ALLOWED-PRICE) ERROR-PRICE-OUT-OF-BOUNDS)
        (var-set current-market-price new-price)
        (var-set oracle-update-block-height stacks-block-height)
        (ok true))
)

(define-public (create-synthetic-tokens (token-amount uint))
    (let (
        (latest-market-price (var-get current-market-price))
    )
    (asserts! (> token-amount u0) ERROR-AMOUNT-MUST-BE-POSITIVE)
    (asserts! (>= token-amount MIN-TOKEN-ISSUANCE-AMOUNT) ERROR-INVALID-TOKEN-QUANTITY)
    (asserts! (<= (- stacks-block-height (var-get oracle-update-block-height)) 
                 PRICE-VALIDITY-PERIOD-BLOCKS) 
              ERROR-ORACLE-DATA-STALE)

    (match (secure-multiply token-amount (/ latest-market-price u100))
        base-collateral-needed 
        (match (secure-multiply base-collateral-needed (/ COLLATERAL-SAFETY-RATIO u100))
            total-collateral-required
            (match (stx-transfer? total-collateral-required tx-sender (as-contract tx-sender))
                transfer-success
                (begin
                    (map-set collateralized-positions tx-sender
                        {
                            staked-collateral: total-collateral-required,
                            issued-synthetic-tokens: token-amount,
                            position-open-price: latest-market-price
                        })
                    (match (secure-add (get-user-token-balance tx-sender) token-amount)
                        updated-user-balance
                        (begin
                            (map-set user-token-holdings tx-sender updated-user-balance)
                            (match (secure-add (var-get global-token-supply) token-amount)
                                new-total-supply
                                (begin
                                    (var-set global-token-supply new-total-supply)
                                    (ok true))
                                error ERROR-CALCULATION-OVERFLOW))
                        error ERROR-CALCULATION-OVERFLOW))
                error ERROR-COLLATERAL-DEPOSIT-INSUFFICIENT)
            error ERROR-CALCULATION-OVERFLOW)
        error ERROR-CALCULATION-OVERFLOW))
)

