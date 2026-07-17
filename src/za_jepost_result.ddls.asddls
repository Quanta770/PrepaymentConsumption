@EndUserText.label: 'Abstract entity for JE posting result'
define abstract entity ZA_JEPOST_RESULT
{
  AccountingDocument : abap.char(10);
  Status             : abap.char(10);   -- 'SUCCESS' or 'ERROR'
  Message            : abap.char(512);
    
}
