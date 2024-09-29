package cui.shibing.biz.common;

import cui.shibing.core.AnnotationSupportModel;
import cui.shibing.core.Attribution;

public class CommonResult extends AnnotationSupportModel {
    @Attribution
    private int code;
    @Attribution
    private String msg;



    public CommonResult error(String msg) {
        code = 1;
        this.msg = msg;
        return this;
    }

    public CommonResult error(int code, String msg) {
        this.code = code;
        this.msg = msg;
        return this;
    }

    public CommonResult success() {
        this.code = 0;
        this.msg = "success";
        return this;
    }

    public int getCode() {
        return code;
    }

    public void setCode(int code) {
        this.code = code;
    }

    public String getMsg() {
        return msg;
    }

    public void setMsg(String msg) {
        this.msg = msg;
    }
}
