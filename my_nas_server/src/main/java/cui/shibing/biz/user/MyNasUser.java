package cui.shibing.biz.user;

import cui.shibing.core.common.CommonResult;
import cui.shibing.core.AnnotationSupportModel;
import cui.shibing.core.Attribution;
import cui.shibing.core.Event;
import cui.shibing.core.Storable;
import cui.shibing.core.Param;

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
    public CommonResult register(@Param("accountType") String accountType, @Param("account") String account,
                                 @Param("password") String password, @Param("userName") String userName) {
        this.accountType = accountType;
        this.account = account;
        this.password = password;
        this.userName = userName;

        if (this.exist()) {
            return new CommonResult().error("用户已经存在");
        }

        this.save(this);
        return new CommonResult().success();
    }

    @Event
    public CommonResult updatePassword(@Param("password") String password) {
        if (!exist()) {
            return new CommonResult().error("账号不存在");
        }
        this.password = password;
        this.save(this);
        return new CommonResult().success();
    }

}
