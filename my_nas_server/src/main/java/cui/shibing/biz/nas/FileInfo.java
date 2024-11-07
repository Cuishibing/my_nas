package cui.shibing.biz.nas;

import cui.shibing.core.common.CommonResult;
import cui.shibing.core.common.Md5Util;
import cui.shibing.core.AnnotationSupportModel;
import cui.shibing.core.Attribution;
import cui.shibing.core.Event;
import cui.shibing.core.Storable;
import cui.shibing.core.common.FileResult;

public class FileInfo extends AnnotationSupportModel implements Storable {

    @Attribution
    private String fileName;

    @Attribution
    private String filePath;

    @Attribution
    private String userAccount;

    @Attribution
    private String md5;

    public FileInfo(){}

    public FileInfo(String fileName, String filePath, String userAccount) {
        this.fileName = fileName;
        this.filePath = filePath;
        this.userAccount = userAccount;
        this.md5 = Md5Util.getMd5(filePath);
    }
    
    @Event
    public Object getFileData() {
        if (!exist()) {
            return new CommonResult().error("文件不存在");
        }
        return new FileResult(filePath);
    }

    @Override
    public String getIdentifier() {
        return "%s_%s".formatted(userAccount, md5);
    }
}
