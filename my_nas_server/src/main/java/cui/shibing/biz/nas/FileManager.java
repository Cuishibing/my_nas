package cui.shibing.biz.nas;

import cui.shibing.core.common.CommonResult;
import cui.shibing.core.*;
import jakarta.servlet.http.Part;
import org.apache.commons.collections.CollectionUtils;
import org.apache.commons.lang3.StringUtils;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/**
 * 文件管理器，每个人都有一个自己的实例，可以针对性的进行配置
 */
public class FileManager extends AnnotationSupportModel implements Storable {

    public enum FileType {
        picture, music
    }

    @Attribution
    private String fileRootPath;

    @Attribution
    private String userAccount;

    @Attribution
    private List<FileType> fileTypes;

    @Override
    public void init() {
        if (StringUtils.isBlank(fileRootPath)) {
            fileRootPath = "/Users/peggy/Desktop/my_nas";
        }
        if (CollectionUtils.isEmpty(fileTypes)) {
            fileTypes = new ArrayList<>();
            fileTypes.add(FileType.picture);
        }
    }

    @Override
    public String getIdentifier() {
        return userAccount;
    }

    @Event
    public CommonResult createFileManager(@Param("userAccount") String userAccount,
            @Param("fileRootPath") String fileRootPath) {
        if (StringUtils.isBlank(userAccount)) {
            return new CommonResult().error("用户账号为空");
        }
        this.userAccount = userAccount;
        this.fileRootPath = fileRootPath;
        this.save(this);
        return new CommonResult().success();
    }

    @Event
    public CommonResult uploadFile(@Param("file") Part file, @Param("fileType") String fileType)
            throws IOException {
        if (!exist()) {
            return new CommonResult().error("文件管理器不存在");
        }
        String fileName = file.getSubmittedFileName();
        if (StringUtils.isBlank(fileName)) {
            return new CommonResult().error("文件名为空");
        }

        FileType ft = FileType.valueOf(fileType);

        String filePath = Path.of(fileRootPath, userAccount, ft.name().toLowerCase(), file.getSubmittedFileName())
                .toString();

        File f = new File(filePath);
        if (!f.exists()) {
            f.getParentFile().mkdirs();
        }
        file.write(filePath);

        FileInfo fileInfo = new FileInfo(file.getSubmittedFileName(), filePath, userAccount);
        fileInfo.save(fileInfo);

        return new CommonResult().success(fileInfo.populate());
    }

}
