@AbapCatalog.sqlViewName: 'ZV_CONSUMP_SUM'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Aggregation of consumption'
@Metadata.ignorePropagatedAnnotations: true
define view ZI_CONSUMPTION_AGGR as select from ZI_CONSUMPTION_HISTORY
{
    key Salesorder        as Salesorder,
  key Salesorderitem    as Salesorderitem,
  @Semantics.amount.currencyCode: 'Currency'
      sum(Soamount)     as ConsumedSOAmount,
      Socurrency        as Currency
    
}
group by
  Salesorder,
  Salesorderitem,
  Socurrency
