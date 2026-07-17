@EndUserText.label: 'Staging Rows Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZC_OPENIO_STAGING_ROWS
  as projection on ZI_OPENIO_STAGING_ROWS
{
    key SapUuid,
    SessionId,
    PrepaymentReqNumPrepayment,
    PrepaymentSo,
    PrepaymentSoItem,
    PrepaymentSalesOrg,
    PrepaymentSoldTo,
    PrepaymentScenarioPy,
    PrepaymentCurrency,
    PrepaymentNetAmount,
    PrepaymentRemainingAmount,
    PrepayDocDate,
    DelvSoSalesDocument,
    DelvSoSalesDocumentItem,
    DelvSoSalesOrg,
    DelvSoSoldTo,
    DelvSoScenario,
    DelvSoCurrency,
    DelvSoNetAmount,
    DelvRemainingAmount,
    DelvDocDate,
    CreatedOn
    
}
