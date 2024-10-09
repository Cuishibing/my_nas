package cui.shibing.biz.testmodel;

import cui.shibing.core.AnnotationSupportModel;
import cui.shibing.core.Event;
import cui.shibing.core.EventObj;

public class DuplicateEventModel extends AnnotationSupportModel {
   @Event
    public void event1(EventObj e) {

   }

    @Event("event1")
    public void dEvent(EventObj e) {

    }
}
