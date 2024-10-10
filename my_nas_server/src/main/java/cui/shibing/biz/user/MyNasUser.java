package cui.shibing.biz.user;

import cui.shibing.core.AnnotationSupportModel;
import cui.shibing.core.Attribution;
import cui.shibing.core.Event;
import cui.shibing.core.EventObj;
import cui.shibing.core.Storable;

public class MyNasUser extends AnnotationSupportModel implements Storable {

    @Attribution
    private String account;
    @Attribution
    private String password;

    @Override
    public String getIdentifier() {
        return account;
    }

    @Event
    public String sayHello(EventObj e) {
        return "hello";
    }

}
