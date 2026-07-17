@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption history for SalesOrder'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_CONSUMPTION_HISTORY as select from ztb_consume_hist
{
    
  key sap_uuid as SapUuid,
  key salesorder as Salesorder,
  key salesorderitem as Salesorderitem,
  billingplanitem as Billingplanitem,
  socurrency as Socurrency,
  @Semantics.amount.currencyCode: 'Socurrency'
  soamount as Soamount,
  changedatetime as Changedatetime,
  @Semantics.user.lastChangedBy: true
  lastchangedby as Lastchangedby,
  prepaymentreqnum as Prepaymentreqnumber,
  sotype as Sotype,
  iotype as IOType,
  @Semantics.amount.currencyCode: 'Socurrency'
  openamount as Openamount
}
