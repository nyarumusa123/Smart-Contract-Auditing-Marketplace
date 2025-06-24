# Smart Contract Auditing Marketplace

A comprehensive blockchain-based platform that connects security auditors with projects needing code reviews. The marketplace features standardized audit processes, vulnerability scoring, auditor certification systems, and secure payment handling.

## Features

### 🔐 Auditor Certification System
- **Multi-tier certification**: None, Basic, Professional, Expert
- **Requirement-based upgrades**: Based on audit count, success rate, and reputation
- **Expiring certifications**: Ensures auditors maintain current skills
- **Specialization tracking**: Auditors can specify expertise areas

### 📋 Standardized Audit Process
- **Vulnerability classification**: 5-level severity system (Info, Low, Medium, High, Critical)
- **Detailed reporting**: Category, description, remediation, and line number tracking
- **Scoring algorithm**: Weighted scoring based on vulnerability severity
- **Report integrity**: Hash-based report verification

### 💰 Secure Payment System
- **Escrow protection**: Funds held securely until audit completion
- **Platform fees**: Configurable fee structure (default 2.5%)
- **Rating-based release**: Payment released upon client satisfaction
- **Dispute handling**: Built-in dispute resolution framework

### 📊 Reputation Management
- **Dynamic scoring**: Performance-based reputation calculation
- **Success tracking**: Monitors completion rates and client satisfaction
- **Experience bonuses**: Additional reputation for experienced auditors
- **Transparency**: Public auditor profiles and statistics

## Contract Architecture

### Core Data Structures

#### Auditors
```clarity
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
```

#### Projects
```clarity
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
```

#### Audits
```clarity
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
```

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Stacks CLI](https://docs.stacks.co/docs/command-line-interface) (optional)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd audit-marketplace
```

2. Check the contract:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

### Deployment

1. Deploy to testnet:
```bash
clarinet deployments generate --testnet
clarinet deployments apply --testnet
```

2. Deploy to mainnet:
```bash
clarinet deployments generate --mainnet
clarinet deployments apply --mainnet
```

## Usage Guide

### For Contract Owners

#### Initialize Certification Standards
```clarity
(contract-call? .audit-marketplace initialize-certification-standards)
```

### For Auditors

#### 1. Register as Auditor
```clarity
(contract-call? .audit-marketplace register-auditor
  (list "solidity" "smart-contracts" "defi")
  u1000000) ;; 1 STX per hour
```

#### 2. Apply for Certification
```clarity
(contract-call? .audit-marketplace apply-for-certification u1) ;; Basic level
```

#### 3. Accept Audit Assignment
```clarity
(contract-call? .audit-marketplace accept-audit u1) ;; Project ID 1
```

#### 4. Submit Audit Results
```clarity
(contract-call? .audit-marketplace submit-audit-results
  u1 ;; audit-id
  (list
    { severity: u5, category: "reentrancy", description: "...", remediation: "...", line-number: (some u42) }
    { severity: u3, category: "access-control", description: "...", remediation: "...", line-number: (some u67) }
  )
  "0x1234...abcd") ;; report hash
```

### For Project Owners

#### 1. Submit Project for Audit
```clarity
(contract-call? .audit-marketplace submit-project
  "DeFi Protocol Audit"
  "Comprehensive security audit for our lending protocol"
  "https://github.com/project/repo"
  u10000000 ;; 10 STX budget
  u1440 ;; 10 days deadline
  u2 ;; Professional certification required
  "defi") ;; DeFi specialization
```

#### 2. Rate Auditor and Release Payment
```clarity
(contract-call? .audit-marketplace rate-and-pay u1 u5) ;; Audit ID 1, 5-star rating
```

## API Reference

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `register-auditor` | Register new auditor | specializations, hourly-rate |
| `apply-for-certification` | Upgrade certification level | target-level |
| `submit-project` | Submit audit request | title, description, repo, budget, deadline, cert-level, specialization |
| `accept-audit` | Accept audit assignment | project-id |
| `submit-audit-results` | Submit audit findings | audit-id, vulnerabilities, report-hash |
| `rate-and-pay` | Rate auditor and release payment | audit-id, rating |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-auditor` | Get auditor details | Auditor data |
| `get-project` | Get project details | Project data |
| `get-audit` | Get audit details | Audit data |
| `get-auditor-by-principal` | Find auditor by principal | Auditor data |
| `get-vulnerability` | Get vulnerability details | Vulnerability data |
| `get-platform-stats` | Get platform statistics | Stats object |

## Certification Levels

| Level | Requirements | Fee | Duration |
|-------|-------------|-----|----------|
| **Basic** | 5 audits, 80% success rate, 60 reputation | 1 STX | 1 year |
| **Professional** | 15 audits, 85% success rate, 75 reputation | 2.5 STX | 1 year |
| **Expert** | 50 audits, 90% success rate, 85 reputation | 5 STX | 1 year |

## Vulnerability Severity Levels

| Level | Weight | Description |
|-------|--------|-------------|
| **Critical** | 100 | Immediate threat to funds or system integrity |
| **High** | 50 | Significant security risk requiring prompt attention |
| **Medium** | 25 | Moderate risk that should be addressed |
| **Low** | 10 | Minor issues with minimal impact |
| **Info** | 5 | Informational findings and best practices |

## Security Considerations

- **Escrow Protection**: All project funds are held in escrow until audit completion
- **Certification Verification**: Only certified auditors can accept projects requiring certification
- **Deadline Enforcement**: Strict deadline management prevents stale audits
- **Reputation System**: Performance-based reputation prevents gaming
- **Payment Security**: Secure STX transfers with platform fee collection
