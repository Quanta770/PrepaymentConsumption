@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reference 3 by Config Value'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_OPPACCITEM_REF3 as select from I_OperationalAcctgDocItem as Opp
 left outer join ZR_CONFIG_VALUE           as prefix on  prefix.Category    = Opp.CompanyCode
                                                        and prefix.ParameterID = 'InvoicePrefix'
{
   key Opp.CompanyCode,
   key Opp.FiscalYear,  
   Opp.Reference1IDByBusinessPartner ,
    Opp.Reference2IDByBusinessPartner ,
   Opp.Reference3IDByBusinessPartner
}
where 
left(Opp.Reference3IDByBusinessPartner,3 ) = prefix.Value1
or Opp.Reference3IDByBusinessPartner  is initial
