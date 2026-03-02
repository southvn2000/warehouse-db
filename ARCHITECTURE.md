# Australia Logistic SQL Project Architecture

## 1) Overview
This repository is a **database-first SQL Server backend** for a 3PL/WMS platform.  
Business workflows are implemented primarily through stored procedures, with tables and user-defined table types (TVPs) as the core persistence and contract layers.

Top-level object inventory (current repo snapshot):
- **Functions**: 5 files
- **StoreProcedures**: 543 files
- **Tables**: 136 files
- **Types**: 34 files

This indicates a **procedure-centric architecture** where application services likely call SQL procedures directly for both reads and writes.

---

## 2) Architectural Style

### Database-as-Service Layer
- `StoreProcedures/` is the main application API surface.
- Procedures encapsulate validation, workflow transitions, and persistence.
- Table-valued parameters are heavily used to pass arrays/batch payloads.

### Modular-by-Domain Naming
Most procedures follow this naming structure:
- `SP_VI_TBL_<Domain>_<Action>`

Examples:
- `SP_VI_TBL_Orders_InsertOrder`
- `SP_VI_TBL_Wave_StartWaveRequest`
- `SP_VI_TBL_ULD_ChangeULDLocation`
- `SP_VI_TBL_Report_RunReportByID`

There is also an integration-oriented naming stream:
- `sp_DHL_*`
- `sp_CP_*`

---

## 3) Core Layers and Responsibilities

## 3.1 Data Model Layer (`Tables/`)
Key groups:
- **Master/Identity**: `Tenant`, `Users`, `LocWarehouse`, `Items`
- **Order/Fulfilment**: `Orders`, `OrdersLine`, `Fulfilment`, `FulfilmentLine`
- **Warehouse Stock/Movement**: `ULD`, `ULDLine`, location hierarchy (`LocArea`, `LocSection`, `LocRow`, `LocColumn`, `LocShelf`, `LocBin`, `LocSBin`)
- **Execution Pipelines**: `Wave`, `WaveLine`, picking/packing schedules and results
- **Integration**: `AP*`, `DHL*`, `CP*`, `ManualIntegration`
- **Billing/Reporting**: `Invoice`, `Report*`, `Dashboard*`
- **Security/Audit**: `UserPermission`, `SecurityLog`, `Log`, `IPAddressStatusList`

Common schema conventions:
- Soft-delete column: `Deleted` (frequently filtered as `Deleted = 0`)
- Audit columns: `CreatedDateTime`, `CreatedBy`, `FirstEditedDateTime`, `FirstEditedBy`, `LastEditedDateTime`, `LastEditedBy`
- Natural business keys alongside identity PKs (e.g., `OrderID` + `order_number`)

## 3.2 Procedure Layer (`StoreProcedures/`)
Main behavior patterns:
- **CRUD + domain actions** (insert/update/view/list/delete + process-step transitions)
- **Transactional boundaries** with `BEGIN TRANSACTION` + `TRY/CATCH`
- **Business validation and message output** via `@Message VARCHAR(4000) OUTPUT`
- **Procedure orchestration** (procedures calling other procedures for sub-flows)

Examples:
- `SP_VI_TBL_Orders_InsertOrder` validates tenant/warehouse/carrier mapping, inserts order + lines + history.
- `SP_VI_TBL_Wave_StartWaveRequest` handles wave phase transitions (Picking/Sorting/Packing/Mailing), updates wave, lines, and fulfilment statuses.
- `SP_VI_TBL_APShipment_InsertAPShipment` routes to local/international AP shipment generation procedures based on service resolution.
- `sp_DHL_Response_JSON` parses JSON payloads into TVPs and delegates to `sp_DHL_Response`.

## 3.3 Function Layer (`Functions/`)
Scalar helper functions support read transformations/computations:
- Country/location formatting helpers
- Inventory helper (`fn_GetStockOnHandOfTenantItem`) computes stock from `ULD` + `ULDLine` with business filters (hold/status/transaction type)

## 3.4 Type Layer (`Types/`)
User-defined table types provide strongly typed bulk interfaces.
Examples:
- Generic collections: `IdArray`, `StringArray`, `ParameterArray`, `ValueArray`
- Domain payloads: `OrderLineType`, `BoxSizeType`, `StockTakeResultType`, integration mapping types

This supports efficient set-based processing and reduces row-by-row API calls.

---

## 4) Domain Workflow Architecture

## 4.1 Order-to-Dispatch (high level)
1. Create order (`Orders`, `OrdersLine`)  
2. Copy/prepare fulfilment (`Fulfilment`, `FulfilmentLine`)  
3. Group into wave (`Wave`, `WaveLine`)  
4. Execute picking/sorting/packing/mailing transitions  
5. Create carrier shipment (AP / DHL / CP / Manual)  
6. Persist shipping responses and tracking artifacts  
7. Generate billing/report outputs

## 4.2 Inventory Control Pattern
- Stock represented by `ULD` containers and `ULDLine` transactions.
- Availability logic consistently filters soft-deleted and non-available statuses.
- Service and wave operations update stock states through dedicated procedures.

## 4.3 Multi-Carrier Integration Pattern
- Tenant + warehouse scoped integration records (`*Integration`, `*IntegrationLine`).
- Service mapping resolves external carrier service from internal order context.
- Dedicated procedures for each carrier family and response persistence.

---

## 5) Cross-Cutting Patterns

### 5.1 Soft Delete Everywhere
Most reads/writes include `Deleted = 0`, showing logical deletion as a standard data lifecycle policy.

### 5.2 Auditability
Most mutable entities track creation and edit metadata. Some flows also insert explicit history rows (e.g., `OrderHistory`).

### 5.3 Contracted Error Messaging
Many write/action procedures expose business errors through output parameters (`@Message`) instead of throwing to caller.

### 5.4 Procedure-Orchestrated Transactions
Complex operations compose multiple table updates and child procedure calls inside transactions.

### 5.5 Dynamic SQL in List/Search Procedures
Several list/report procedures use dynamic SQL for sorting/filtering/pagination; parameterization quality should be reviewed where user input is involved.

---

## 6) Integration Boundaries
Likely external boundaries (from naming and structure):
- Application/API server calling SQL procedures as service endpoints
- Carrier APIs (Australia Post, DHL, Courier Please)
- Reporting/export consumers
- Mobile/warehouse operator clients (task-oriented wave/service procedures)

The database is both:
- **System of record**, and
- **Primary business logic execution engine**.

---

## 7) Risks and Maintainability Notes
- High procedure count (543) increases coupling and change coordination effort.
- Long, monolithic procedures (e.g., wave operations) can be hard to test and reason about.
- Dynamic SQL usage in list/search areas should be consistently parameterized and validated.
- Soft-delete discipline is strong, but strict indexing and query standards are required to keep performance stable.

---

## 8) Suggested Next Architecture Improvements
1. Add a generated data dictionary (table/procedure/type dependencies and ERD).  
2. Introduce module-level architecture docs (Orders, Wave, Inventory, Carrier, Billing, Reporting).  
3. Standardize stored-procedure template (transaction, error handling, output contract).  
4. Add static checks for dynamic SQL safety and missing `Deleted = 0` guards.  
5. Introduce integration test harness for critical workflows (Order -> Wave -> Shipment -> Invoice).

---

## 9) Representative Files Reviewed
- `StoreProcedures/dbo.SP_VI_TBL_Orders_InsertOrder.StoredProcedure.sql`
- `StoreProcedures/dbo.SP_VI_TBL_Wave_StartWaveRequest.StoredProcedure.sql`
- `StoreProcedures/dbo.SP_VI_TBL_APShipment_InsertAPShipment.StoredProcedure.sql`
- `StoreProcedures/dbo.SP_VI_TBL_Users_CheckAPIAuthentication.StoredProcedure.sql`
- `StoreProcedures/dbo.sp_DHL_Response_JSON.StoredProcedure.sql`
- `StoreProcedures/dbo.SP_VI_TBL_Report_RunReportByID.StoredProcedure.sql`
- `Tables/dbo.Orders.Table.sql`
- `Tables/dbo.ULD.Table.sql`
- `Functions/dbo.fn_GetStockOnHandOfTenantItem.UserDefinedFunction.sql`
- `Types/dbo.OrderLineType.UserDefinedTableType.sql`

This document describes the current architecture inferred from repository SQL objects and naming conventions.
