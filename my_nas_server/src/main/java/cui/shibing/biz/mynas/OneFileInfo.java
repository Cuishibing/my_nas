package cui.shibing.biz.mynas;

import cui.shibing.core.AnnotationSupportModel;
import cui.shibing.core.Attribution;
import cui.shibing.core.Storable;

public class OneFileInfo extends AnnotationSupportModel implements Storable {

    @Attribution
    private String md5;// 文件内容md5

    @Attribution
    private Long createTime;// 创建时间

    @Attribution
    private String path; // 文件路径

    @Override
    public String getIdentifier() {
        return md5;
    }

    public String getMd5() {
        return md5;
    }

    public void setMd5(String md5) {
        this.md5 = md5;
    }

    public Long getCreateTime() {
        return createTime;
    }

    public void setCreateTime(Long createTime) {
        this.createTime = createTime;
    }

    public String getPath() {
        return path;
    }

    public void setPath(String path) {
        this.path = path;
    }
}
