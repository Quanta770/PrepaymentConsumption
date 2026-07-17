@ClientHandling: {
  type: #CLIENT_DEPENDENT,          // required
  algorithm: #SESSION_VARIABLE      // or #PARAMETER
}
@EndUserText.label: 'FIFO algorithm to match open IO rows'
define table function ZI_OPENIO_ROWS_MATCHING
returns {
  
  RCLNT                      : mandt;
  SAPUUID                    : sysuuid_x16;
  SESSIONID                  : abap.char(32);
  PREPAYMENTREQNUMPREPAYMENT : abap.char(10);
  PREPAYMENTSO               : abap.char(10);
  PREPAYMENTSOITEM           : abap.char(6);
  PREPAYMENTSALESORG         : abap.char(4);
  PREPAYMENTSOLDTO           : abap.char(10);
  PREPAYMENTSCENARIOPY       : abap.char(1);
  PREPAYMENTCURRENCY         : abap.cuky;
  PREPAYMENTNETAMOUNT        : abap.curr(23,2);
  PREPAYMENTREMAININGAMOUNT  : abap.curr(23,2);
  PREPAYDOCDATE              : abap.dats;
  DELVSOSALESDOCUMENT        : abap.char(10);
  DELVSOSALESDOCUMENTITEM    : abap.char(6);
  DELVSOSALESORG             : abap.char(4);
  DELVSOSOLDTO               : abap.char(10);
  DELVSOSCENARIO             : abap.char(10);
  DELVSOCURRENCY             : abap.cuky;
  DELVSONETAMOUNT            : abap.curr(23,2);
  DELVREMAININGAMOUNT        : abap.curr(23,2);
  DELVDOCDATE                : abap.dats;
  DELVSOAMOUNT_ADJ           : abap.curr(23,2);
  
}
implemented by method ZCL_OPENIO_PREPAY_DELV=>EXECUTE;