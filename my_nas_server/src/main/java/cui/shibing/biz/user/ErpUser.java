package cui.shibing.biz.user;

import cui.shibing.core.AnnotationSupportModel;
import cui.shibing.core.Attribution;
import cui.shibing.core.Storable;

public class ErpUser extends AnnotationSupportModel implements Storable {

    @Attribution
    private String account;
    @Attribution
    private String password;

    @Override
    public String getIdentifier() {
        return account;
    }

    public String getAccount() {
        return account;
    }

    public void setAccount(String account) {
        this.account = account;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }


}
