package cui.shibing.biz.user;

import cui.shibing.biz.common.CommonResult;
import cui.shibing.core.AnnotationSupportModel;
import cui.shibing.core.Attribution;
import cui.shibing.core.Event;
import cui.shibing.core.EventObj;
import cui.shibing.core.ModelFactory;
import cui.shibing.core.Storable;

public class MyNasUser extends AnnotationSupportModel implements Storable {
    @Attribution
    private String accountType;
    @Attribution
    private String account;
    @Attribution
    private String password;
    @Attribution
    private String userName;

    @Override
    public String getIdentifier() {
        return account;
    }

    @Event
    public CommonResult register(EventObj e) {
        if (this.exist()) {
            return new CommonResult().error("用户已经存在");
        }

        this.save(this);

        return new CommonResult().success();
    }

    @Event
    public CommonResult updateInfo(EventObj e) {
        this.save(this);
        return new CommonResult().success();
    }

}
