package cui.shibing.biz.user;

import cui.shibing.biz.common.CommonResult;
import cui.shibing.core.*;
import org.apache.commons.lang3.StringUtils;

public class UserRegisterModel extends AnnotationSupportModel {

    @Event
    public CommonResult register(EventObj e) {
        String account = e.getAttribution("account");
        String password = e.getAttribution("password");

        if (StringUtils.isBlank(account) || StringUtils.contains(account, " ")) {
            return new CommonResult().error("账号不能为空且不允许包含空格");
        }

        if (account.length() > 18) {
            return  new CommonResult().error("账号长度不能超过18位");
        }

        if (StringUtils.isBlank(password) || StringUtils.contains(password, " ")) {
            return  new CommonResult().error("密码不能为空且不允许包含空格");
        }

        ErpUser existUser = ModelFactory.getModel("ErpUser", account);
        if (existUser.exist()) {
            return new CommonResult().error(String.format("已经存在账号%s", account));
        }
        existUser.setAccount(account);
        existUser.setPassword(password);

        existUser.save(existUser);

        return new CommonResult().success();
    }

}