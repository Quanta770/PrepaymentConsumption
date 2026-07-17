@EndUserText.label: 'Abstract entity for action clearSessionRows response'
define abstract entity ZA_CLEAR_SESSION_ROWS_RESULT
{

      processedCount : abap.int4;
      sessionId      : abap.char(32);
      message        : abap.char(255);
      hasErrors      : abap_boolean;
}
