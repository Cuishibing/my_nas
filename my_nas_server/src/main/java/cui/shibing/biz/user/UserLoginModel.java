package cui.shibing.biz.user;

import cui.shibing.biz.common.CommonResult;
import cui.shibing.core.*;
import org.apache.commons.lang3.StringUtils;

public class UserLoginModel extends AnnotationSupportModel {

        @Attribution
        private String account;

        @Attribution
        private String password;


        @Event
        public CommonResult login(EventObj e) {
            account = e.getAttribution("account");
            password = e.getAttribution("password");

            ErpUser userInfo = ModelFactory.getModel("ErpUser", account);

            if (!userInfo.exist()) {
                return new CommonResult().error("用户不存在");
            }

            if (StringUtils.equals(password, userInfo.getPassword())) {
                return new CommonResult().success();
            }

            return new CommonResult().error("密码错误");
        }

    }