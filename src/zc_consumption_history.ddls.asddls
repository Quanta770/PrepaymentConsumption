@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view of history'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZC_CONSUMPTION_HISTORY as projection on ZI_CONSUMPTION_HISTORY
{
    key SapUuid,
    key Salesorder,
    key Salesorderitem,
    Billingplanitem,
    Socurrency,
    Soamount,
    Changedatetime,
    Lastchangedby,
    Prepaymentreqnumber,
    Sotype,
    IOType,
    Openamount
}
