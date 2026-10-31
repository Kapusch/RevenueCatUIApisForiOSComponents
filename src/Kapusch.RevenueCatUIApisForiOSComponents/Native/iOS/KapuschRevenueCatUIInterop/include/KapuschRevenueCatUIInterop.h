#include <stdint.h>

/* Events delivered to krcui_event_callback. `first` and `second` are unretained Objective-C
   objects (or NULL), valid only during the call:
     1 purchase started     first: RCPackage
     2 purchase initiated   first: RCPackage, token: answer with krcui_resume
     3 purchase completed   first: RCCustomerInfo, second: RCStoreTransaction (may be NULL)
     4 purchase cancelled
     5 purchase failed      first: NSError
     6 restore started
     7 restore initiated    token: answer with krcui_resume
     8 restore completed    first: RCCustomerInfo
     9 restore failed       first: NSError
    10 dismiss requested    (close button or completed purchase; the paywall does not close itself)
    11 dismissed
    12 released             last event; `context` is no longer used afterwards */
typedef void (*krcui_event_callback)(void *context, int32_t event, void *first, void *second, int64_t token);

void *krcui_paywall_new(void *offering, int32_t display_close_button, krcui_event_callback callback, void *context);
int32_t krcui_resume(int64_t token, int32_t proceed);
int32_t krcui_paywall_update_offering(void *controller, void *offering);
int32_t krcui_paywall_update_display_close_button(void *controller, int32_t display);
int32_t krcui_paywall_set_custom_variable(void *controller, const char *key, const char *value);
