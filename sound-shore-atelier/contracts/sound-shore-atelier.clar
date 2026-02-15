;; Sound Shore Atelier - Creative DNA Platform
;; A collaborative art creation platform with traceable contributions and revenue sharing

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-percentage (err u104))
(define-constant err-insufficient-funds (err u105))

;; Data Variables
(define-data-var artwork-nonce uint u0)
(define-data-var contribution-nonce uint u0)

;; Data Maps
(define-map artworks
    uint
    {
        creator: principal,
        title: (string-ascii 100),
        total-contributions: uint,
        total-revenue: uint,
        is-active: bool
    }
)

(define-map contributions
    uint
    {
        artwork-id: uint,
        contributor: principal,
        contribution-type: (string-ascii 50),
        creative-dna-weight: uint,
        timestamp: uint,
        verified: bool
    }
)

(define-map creative-dna-stakes
    {artwork-id: uint, contributor: principal}
    {
        total-weight: uint,
        contribution-count: uint
    }
)

(define-map artwork-revenues
    {artwork-id: uint, contributor: principal}
    uint
)

;; Public Functions

;; Create a new collaborative artwork
(define-public (create-artwork (title (string-ascii 100)))
    (let
        (
            (artwork-id (+ (var-get artwork-nonce) u1))
        )
        (map-set artworks artwork-id
            {
                creator: tx-sender,
                title: title,
                total-contributions: u0,
                total-revenue: u0,
                is-active: true
            }
        )
        (var-set artwork-nonce artwork-id)
        (ok artwork-id)
    )
)

;; Add a contribution to an artwork
(define-public (add-contribution 
    (artwork-id uint)
    (contribution-type (string-ascii 50))
    (creative-dna-weight uint))
    (let
        (
            (artwork (unwrap! (map-get? artworks artwork-id) err-not-found))
            (contribution-id (+ (var-get contribution-nonce) u1))
            (current-stake (default-to 
                {total-weight: u0, contribution-count: u0}
                (map-get? creative-dna-stakes {artwork-id: artwork-id, contributor: tx-sender})
            ))
        )
        ;; Verify artwork is active
        (asserts! (get is-active artwork) err-unauthorized)
        
        ;; Verify valid weight (1-100)
        (asserts! (and (> creative-dna-weight u0) (<= creative-dna-weight u100)) err-invalid-percentage)
        
        ;; Create contribution record
        (map-set contributions contribution-id
            {
                artwork-id: artwork-id,
                contributor: tx-sender,
                contribution-type: contribution-type,
                creative-dna-weight: creative-dna-weight,
                timestamp: block-height,
                verified: false
            }
        )
        
        ;; Update Creative DNA stakes
        (map-set creative-dna-stakes 
            {artwork-id: artwork-id, contributor: tx-sender}
            {
                total-weight: (+ (get total-weight current-stake) creative-dna-weight),
                contribution-count: (+ (get contribution-count current-stake) u1)
            }
        )
        
        ;; Update artwork
        (map-set artworks artwork-id
            (merge artwork {total-contributions: (+ (get total-contributions artwork) u1)})
        )
        
        (var-set contribution-nonce contribution-id)
        (ok contribution-id)
    )
)

;; Verify a contribution (peer review simulation)
(define-public (verify-contribution (contribution-id uint))
    (let
        (
            (contribution (unwrap! (map-get? contributions contribution-id) err-not-found))
            (artwork-id (get artwork-id contribution))
            (artwork (unwrap! (map-get? artworks artwork-id) err-not-found))
        )
        ;; Only artwork creator can verify for now (simplified)
        (asserts! (is-eq tx-sender (get creator artwork)) err-unauthorized)
        
        (map-set contributions contribution-id
            (merge contribution {verified: true})
        )
        (ok true)
    )
)

;; Distribute revenue to contributors based on Creative DNA stakes
(define-public (distribute-revenue (artwork-id uint) (amount uint))
    (let
        (
            (artwork (unwrap! (map-get? artworks artwork-id) err-not-found))
        )
        ;; Only artwork creator can distribute revenue (simplified)
        (asserts! (is-eq tx-sender (get creator artwork)) err-unauthorized)
        
        ;; Update total revenue
        (map-set artworks artwork-id
            (merge artwork {total-revenue: (+ (get total-revenue artwork) amount)})
        )
        (ok true)
    )
)

;; Claim revenue share
(define-public (claim-revenue (artwork-id uint))
    (let
        (
            (stake (unwrap! 
                (map-get? creative-dna-stakes {artwork-id: artwork-id, contributor: tx-sender})
                err-not-found))
            (current-claimed (default-to u0 
                (map-get? artwork-revenues {artwork-id: artwork-id, contributor: tx-sender})))
        )
        ;; Record claimed amount (actual transfer would require STX handling)
        (map-set artwork-revenues 
            {artwork-id: artwork-id, contributor: tx-sender}
            current-claimed
        )
        (ok (get total-weight stake))
    )
)

;; Read-only functions

(define-read-only (get-artwork (artwork-id uint))
    (map-get? artworks artwork-id)
)

(define-read-only (get-contribution (contribution-id uint))
    (map-get? contributions contribution-id)
)

(define-read-only (get-creative-dna-stake (artwork-id uint) (contributor principal))
    (map-get? creative-dna-stakes {artwork-id: artwork-id, contributor: contributor})
)

(define-read-only (get-contributor-revenue (artwork-id uint) (contributor principal))
    (map-get? artwork-revenues {artwork-id: artwork-id, contributor: contributor})
)

(define-read-only (get-artwork-count)
    (ok (var-get artwork-nonce))
)

(define-read-only (get-contribution-count)
    (ok (var-get contribution-nonce))
)