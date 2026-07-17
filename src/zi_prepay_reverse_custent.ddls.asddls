@EndUserText.label: 'Custom Entity to Reverse Journal Entry'
@ObjectModel: {
    query: {
        implementedBy: 'ABAP:ZCL_FI_PREPAY_REVERSE_JE'
    }
}
define custom entity ZI_PREPAY_REVERSE_CUSTENT
 
{
   key AccountingDocument   : abap.char(10);
   key CompanyCode          : abap.char(4);
   key FiscalYear           : abap.char(4);
   PostDate                     : abap.char(10);
   Remarks              : abap.char(256);
  
}
