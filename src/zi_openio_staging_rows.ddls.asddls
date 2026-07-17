@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'View of staging table for open io rows'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_OPENIO_STAGING_ROWS as select from ztb_openio_rows
{
    key sap_uuid as SapUuid,
    session_id as SessionId,
    prepaymentreqnumprepayment as PrepaymentReqNumPrepayment,
    prepaymentso as PrepaymentSo,
    prepaymentsoitem as PrepaymentSoItem,
    prepaymentsalesorg as PrepaymentSalesOrg,
    prepaymentsoldto as PrepaymentSoldTo,
    prepaymentscenariopy as PrepaymentScenarioPy,
    prepaymentcurrency as PrepaymentCurrency,
    @Semantics.amount.currencyCode: 'prepaymentcurrency'
    prepaymentnetamount as PrepaymentNetAmount,
    @Semantics.amount.currencyCode: 'prepaymentcurrency'
    prepaymentremainingamount as PrepaymentRemainingAmount,
    prepaydocdate as PrepayDocDate,
    delvsosalesdocument as DelvSoSalesDocument,
    delvsosalesdocumentitem as DelvSoSalesDocumentItem,
    delvsosalesorg as DelvSoSalesOrg,
    delvsosoldto as DelvSoSoldTo,
    delvsoscenario as DelvSoScenario,
    delvsocurrency as DelvSoCurrency,
    @Semantics.amount.currencyCode: 'delvsocurrency'
    delvsonetamount as DelvSoNetAmount,
    @Semantics.amount.currencyCode: 'delvsocurrency'
    delvremainingamount as DelvRemainingAmount,
    delvdocdate as DelvDocDate,
    created_on as CreatedOn
    
}
