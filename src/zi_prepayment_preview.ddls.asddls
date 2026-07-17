@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Prepayment Preview'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZI_PREPAYMENT_PREVIEW as select from ztb_prepay_prev

{
    key journalentry as journalentry,
    key journalitem as journalitem,
    salesorder as salesorder,
    glaccount as glaccount,
    accountname as accountname,
    debit as debit,
    credit as credit,
    currencycd as currencycd,
    wbselement as wbselement,
    writeoff  as writeoff
}
