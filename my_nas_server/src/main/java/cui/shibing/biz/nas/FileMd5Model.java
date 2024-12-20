package cui.shibing.biz.nas;

import cui.shibing.core.AnnotationSupportModel;
import cui.shibing.core.Attribution;
import cui.shibing.core.Storable;
import cui.shibing.core.common.Md5Util;

import java.io.File;

public class FileMd5Model extends AnnotationSupportModel implements Storable {

    @Attribution
    private String path;

    @Attribution
    private String md5;

    @Attribution
    private Long createTime;

    @Override
    public String getIdentifier() {
        return md5;
    }

    public void calculateMd5(String rawPath) {
        if (rawPath == null || rawPath.isEmpty()) {
            throw new IllegalStateException("文件路径不能为空");
        }

        File file = new File(rawPath);
        if (!file.exists() || !file.isFile()) {
            throw new IllegalStateException("文件不存在或不是一个有效的文件: " + rawPath);
        }

        this.md5 = Md5Util.getPartialContentMd5(rawPath);
    }

    public String getPath() {
        return path;
    }

    public void setPath(String path) {
        this.path = path;
    }

    public String getMd5() {
        return md5;
    }

    public void setMd5(String md5) {
        this.md5 = md5;
    }

    public void setCreateTime(Long createTime) {
        this.createTime = createTime;
    }

    public Long getCreateTime() {
        return createTime;
    }
}
