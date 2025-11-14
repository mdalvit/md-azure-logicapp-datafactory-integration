# Architecture Overview

## System Architecture

```
┌─────────────────┐
│   HTTP Trigger  │
│  (External App) │
└────────┬────────┘
         │
         │ HTTPS POST
         ▼
┌─────────────────────────────────────────┐
│         Azure Logic App                 │
│  ┌───────────────────────────────────┐  │
│  │  System-Assigned Managed Identity │  │
│  └───────────────┬───────────────────┘  │
│                  │                       │
│  ┌───────────────▼───────────────────┐  │
│  │   HTTP Action (Built-in)          │  │
│  │   • POST to ARM API               │  │
│  │   • Managed Identity Auth         │  │
│  └───────────────────────────────────┘  │
└─────────────────┬───────────────────────┘
                  │
                  │ OAuth 2.0 Token Request
                  ▼
         ┌────────────────────┐
         │   Azure AD         │
         │  (Token Issuance)  │
         └────────┬───────────┘
                  │ Access Token
                  │ (1 hour TTL)
                  ▼
    ┌──────────────────────────────────┐
    │  Azure Resource Manager API      │
    │  management.azure.com            │
    └──────────────┬───────────────────┘
                   │
                   │ RBAC Check
                   │ (Data Factory Contributor)
                   ▼
         ┌─────────────────────────┐
         │  Azure Data Factory     │
         │  ┌───────────────────┐  │
         │  │  Pipeline Run     │  │
         │  │  • Execute        │  │
         │  │  • Monitor        │  │
         │  │  • Return Status  │  │
         │  └───────────────────┘  │
         └─────────────────────────┘
```

## Component Responsibilities

### Logic App
- **Trigger Management**: HTTP endpoint for external systems
- **Authentication**: Automatic token acquisition via Managed Identity
- **Orchestration**: Coordinates pipeline execution and monitoring
- **Response Handling**: Processes and returns execution results

### Managed Identity
- **Token Lifecycle**: Automatic acquisition and renewal
- **Zero Secrets**: No credentials stored or managed
- **Scope Isolation**: Limited to specific Data Factory resource
- **Audit Trail**: All actions logged with identity context

### Azure Resource Manager
- **Authorization Gateway**: RBAC enforcement
- **API Endpoint**: Standardized REST interface
- **Rate Limiting**: Request throttling and quotas
- **Audit Logging**: Activity log integration

### Data Factory
- **Pipeline Execution**: Run orchestration engine
- **Status Reporting**: Real-time execution state
- **Parameter Handling**: Dynamic pipeline configuration
- **Error Management**: Failure reporting and retry logic

## Authentication Flow

### Token Acquisition
1. Logic App initiates HTTP action
2. Azure runtime requests token from Azure AD
3. Azure AD validates Managed Identity
4. Token issued with 1-hour expiration
5. Token cached for subsequent requests
6. Automatic renewal before expiration

### RBAC Evaluation
1. Token presented to Azure Resource Manager
2. Claims extracted (identity, scopes)
3. Role assignments queried
4. Permission check against requested action
5. Allow/Deny decision returned
6. Action executed or rejected

## Network Flow

```
┌──────────────────────────────────────────────────────────┐
│                    Internet/VNet                         │
└─────────────────────────┬────────────────────────────────┘
                          │ HTTPS (TLS 1.2+)
                          ▼
              ┌───────────────────────┐
              │  Logic App Endpoint   │
              │  (Public or Private)  │
              └───────────┬───────────┘
                          │
                          │ Internal Azure Backbone
                          │ (Microsoft Network)
                          ▼
              ┌───────────────────────┐
              │   Azure AD Endpoint   │
              │   login.microsoft.com │
              └───────────┬───────────┘
                          │
                          │ Azure Backbone
                          ▼
              ┌───────────────────────┐
              │   ARM API Endpoint    │
              │ management.azure.com  │
              └───────────┬───────────┘
                          │
                          │ Azure Backbone
                          ▼
              ┌───────────────────────┐
              │   Data Factory        │
              │   Regional Endpoint   │
              └───────────────────────┘
```

## Data Flow

### Request Flow
```
Client → Logic App → Azure AD → ARM API → Data Factory
   │         │          │          │           │
   │         │          │          │           └─ Execute Pipeline
   │         │          │          └─ Validate RBAC
   │         │          └─ Issue Token
   │         └─ Build HTTP Request
   └─ Trigger Workflow
```

### Response Flow
```
Data Factory → ARM API → Logic App → Client
      │           │          │          │
      │           │          │          └─ HTTP 200/202 + Run ID
      │           │          └─ Parse Response
      │           └─ Format API Response
      └─ Return Run ID + Status
```

## Scalability Considerations

### Logic App Limits
- **Consumption Plan**:
  - 100,000 executions/month free tier
  - Auto-scaling based on load
  - ~5 second cold start
  
- **Standard Plan**:
  - Dedicated compute
  - Predictable performance
  - <1 second warm start

### Concurrent Executions
- No hard limit (governed by Azure quotas)
- Automatic load distribution
- Throttling at Data Factory level (pipeline concurrency)

### Geographic Distribution
- Deploy Logic Apps in multiple regions
- Use Traffic Manager for failover
- Data Factory supports multi-region triggers

## High Availability

### Logic App HA
- Azure-managed redundancy (3 copies minimum)
- Automatic failover within region
- 99.9% SLA (Standard tier)

### Data Factory HA
- Zone-redundant in supported regions
- Automatic retry on transient failures
- 99.9% SLA

### End-to-End Resilience
```
Primary Region (Active)
   ├─ Logic App A
   ├─ Data Factory A
   └─ Automatic Health Monitoring

Secondary Region (Standby)
   ├─ Logic App B
   ├─ Data Factory B  
   └─ Traffic Manager Failover
```

## Security Layers

1. **Transport**: TLS 1.2+ encryption
2. **Authentication**: Azure AD OAuth 2.0
3. **Authorization**: RBAC with least privilege
4. **Identity**: Managed Identity (no secrets)
5. **Network**: Optional private endpoints
6. **Audit**: Activity logs and diagnostics
7. **Compliance**: SOC 2, ISO 27001, GDPR
8. **Monitoring**: Azure Monitor integration

## Performance Characteristics

### Typical Latencies
- Token acquisition: 100-300ms (cached: <10ms)
- ARM API call: 200-500ms
- Pipeline trigger: 500-1000ms
- Total end-to-end: 1-2 seconds

### Optimization Strategies
- Token caching (automatic)
- Connection pooling (built-in)
- Async execution patterns
- Batch operations where possible

## Cost Model

### Logic App Costs
- **Consumption**: Pay per execution
  - $0.000025 per action execution
  
- **Standard**: Monthly fee + execution costs
  - Base: $0.288/hour (~$213/month)
  - Actions: $0.000010 per execution

### Example Monthly Cost (1000 executions/day)
- Consumption: ~$2.25/month
- Standard: ~$216/month (includes 20M executions)

### Data Factory Costs
- Pipeline orchestration: $0.001 per run
- Activity execution: Varies by type
- Data movement: Based on DIU hours

## Monitoring & Observability

### Key Metrics
- Logic App run duration
- Success/failure rate
- Token acquisition time
- API response time
- Pipeline execution duration

### Diagnostic Logs
```json
{
  "category": "WorkflowRuntime",
  "level": "Information",
  "operationName": "Microsoft.Logic/workflows/runs/actions/write",
  "properties": {
    "resource": "Create_ADF_Pipeline_Run",
    "status": "Succeeded",
    "duration": 1234
  }
}
```

### Alerting Strategy
- Alert on failed runs (>5% failure rate)
- Alert on slow executions (>5 seconds)
- Alert on RBAC denials
- Alert on quota exhaustion
