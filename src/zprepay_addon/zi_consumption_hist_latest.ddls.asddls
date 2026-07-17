
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Latest Records from consumption History'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CONSUMPTION_HIST_LATEST as select from ztb_consume_hist
{
    
  //key sap_uuid as SapUuid,
  key salesorder as Salesorder,
  key salesorderitem as Salesorderitem,
  //billingplanitem as Billingplanitem,
  socurrency as Socurrency,
  @Semantics.amount.currencyCode: 'Socurrency'
  sum(soamount) as Soamount,
  max(changedatetime) as Changedatetime,
  lastchangedby as Lastchangedby,
  max(prepaymentreqnum )as Prepaymentreqnumber,
  sotype as Sotype
  
}
where prepaymentreqnum  is not initial
group by 
//sap_uuid,
salesorder,
salesorderitem,
//billingplanitem,
socurrency,
lastchangedby,
prepaymentreqnum,
sotype

