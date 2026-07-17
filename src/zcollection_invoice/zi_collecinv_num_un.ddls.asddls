@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Union of REF3 and XBLNR'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_COLLECINV_NUM_UN
  as select from ZI_DOCREFID_GET
{
  key CompanyCode,
  key FiscalYear,
   cast( max ( DocumentReferenceID ) as abap.char(20) ) as DocumentReferenceID
    
}
//where
//  DocumentReferenceID is not initial
  group by CompanyCode,FiscalYear
union

select from ZI_OPPACCITEM_REF3
{
  key CompanyCode,
  key FiscalYear,

     max( Reference3IDByBusinessPartner ) as DocumentReferenceID
}
//where
//      Reference3IDByBusinessPartner is not initial
//  and Reference2IDByBusinessPartner is not null
//  and Reference2IDByBusinessPartner != ''
//  and Reference2IDByBusinessPartner is not initial
  group by CompanyCode,FiscalYear
union

select from ZI_OPPACCITEM_REF3
{
  key CompanyCode,
  key FiscalYear,

     max( Reference1IDByBusinessPartner ) as DocumentReferenceID
}
//where
//      Reference1IDByBusinessPartner is not initial
//  and Reference2IDByBusinessPartner is not null
//  and Reference2IDByBusinessPartner != ''
//  and Reference2IDByBusinessPartner is not initial
  group by CompanyCode,FiscalYear
  
  union 
  
  select from ZR_CONFIG_VALUE as config
  left outer join       ZR_CONFIG_VALUE as prefix on  prefix.Category    = config.Value1
                                                    and prefix.ParameterID = 'InvoicePrefix'
  {
    key cast( config.Value1   as bukrs ) as CompanyCode,
    key cast( config.Category as gjahr) as FiscalYear,
    
    cast( max( concat(prefix.Value1, config.Value2 )) as abap.char(20)) as DocumentReferenceID
  }
  where config.ParameterID = 'CollectionINV'
  
  group by config.Category, config.Value1 
