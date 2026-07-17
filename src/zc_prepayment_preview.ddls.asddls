@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for Prepayment Preview'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZC_PREPAYMENT_PREVIEW as projection on ZI_PREPAYMENT_PREVIEW
{
    key journalentry,
    key journalitem,
    salesorder,
    glaccount,
    accountname,
    debit,
    credit,
    currencycd,
    wbselement,
    writeoff
}
