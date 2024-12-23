package cui.shibing.biz.nas;

import cui.shibing.core.*;
import cui.shibing.store.entity.QTModel;
import cui.shibing.store.entity.TModel;

import java.io.*;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;

public class FileManageModel extends AnnotationSupportModel {

    private static final String rootFilePath = "/Users/peggy/Desktop/my_nas";
    private static final int PAGE_SIZE = 20;

    @Override
    public void init() {
        super.init();
        
        File rootDir = new File(rootFilePath);
        if (!rootDir.exists()) {
            boolean created = rootDir.mkdirs();
            if (!created) {
                throw new RuntimeException("无法创建根目录: " + rootFilePath);
            }
        }
    }

    @Event
    public boolean fileExist(@Param("md5") String md5, @Param("fileName") String fileName) {
        if (md5 == null || fileName == null) {
            return false;
        }
        ModelFactory.Condition condition = new ModelFactory.Condition();
        condition.and("name", fileName).and("md5", md5);
        Model model = ModelFactory.getModel(FileMd5Model.class.getSimpleName(), condition);
        return model != null;
    }

    @Event
    public boolean uploadFile(@Param("path") String path, @Param("name") String fileName, 
                            @Param("createTime") Long createTime, @Param("file") InputStream file) {
        if (path == null || path.isEmpty() || file == null || fileName == null || fileName.isEmpty()) {
            return false;
        }

        // 清理路径中的特殊字符，防止目录遍历攻击
        path = path.replaceAll("\\.\\./", "")
                  .replaceAll("\\.\\.\\\\", "");

        try {
            // 构建完整的目标路径（包含文件名）
            Path fullPath = Paths.get(rootFilePath, path, fileName);
            File targetFile = fullPath.toFile();

            // 检查目标路径是否在rootFilePath目录下
            if (!targetFile.getAbsolutePath().startsWith(new File(rootFilePath).getAbsolutePath())) {
                return false;
            }

            // 确保所有父目录都存在
            File parentDir = targetFile.getParentFile();
            if (!parentDir.exists()) {
                boolean created = parentDir.mkdirs();
                if (!created) {
                    return false;
                }
            }
            
            // 直接写入目标文件（如果存在则覆盖）
            try (FileOutputStream fos = new FileOutputStream(targetFile)) {
                byte[] buffer = new byte[8192];
                int bytesRead;
                while ((bytesRead = file.read(buffer)) != -1) {
                    fos.write(buffer, 0, bytesRead);
                }
            }

            // 如果需要设置文件创建时间
            if (createTime != null && createTime > 0) {
                targetFile.setLastModified(createTime);
            }

            // 创建并保存FileMd5Model
            FileMd5Model md5Model = new FileMd5Model();
            md5Model.setName(fileName);
            md5Model.setPath(Path.of(path, fileName).toString());
            md5Model.calculateMd5(targetFile.getAbsolutePath());
            md5Model.setCreateTime(createTime);
            return md5Model.save(md5Model);
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    @Event
    public List<FileInfo> listFiles(@Param("path") String path, @Param("page") Integer page) {
        if (path == null) {
            path = "";
        }
        if (page == null || page < 1) {
            page = 1;
        }

        // 清理路径中的特殊字符
        path = path.replaceAll("\\.\\./", "")
                  .replaceAll("\\.\\.\\\\", "");

        try {
            Path dirPath = Paths.get(rootFilePath, path);
            File dir = dirPath.toFile();

            if (!dir.exists() || !dir.isDirectory()) {
                return Collections.emptyList();
            }

            // 创建一个列表来存储所有文件
            List<FileInfo> fileInfoList = new ArrayList<>();
            // 递归获取所有文件
            collectFiles(dir, fileInfoList, dirPath);

            // 按创建时间倒序排序
            fileInfoList.sort((f1, f2) -> Long.compare(f2.getCreateTime(), f1.getCreateTime()));

            // 计算分页
            int startIndex = (page - 1) * PAGE_SIZE;
            int endIndex = Math.min(startIndex + PAGE_SIZE, fileInfoList.size());

            // 如果起始索引超出范围，返回空列表
            if (startIndex >= fileInfoList.size()) {
                return Collections.emptyList();
            }

            return fileInfoList.subList(startIndex, endIndex);
        } catch (Exception e) {
            e.printStackTrace();
            return Collections.emptyList();
        }
    }

    // 新增递归方法来收集所有文件
    private void collectFiles(File dir, List<FileInfo> fileInfoList, Path basePath) {
        File[] files = dir.listFiles();
        if (files == null) {
            return;
        }

        for (File file : files) {
            if (file.isFile()) {
                // 计算相对路径
                String relativePath = basePath.relativize(file.toPath()).toString();
                fileInfoList.add(new FileInfo(
                    file.getName(),
                    file.length(),
                    file.lastModified(),
                    relativePath
                ));
            } else if (file.isDirectory()) {
                // 递归处理子目录
                collectFiles(file, fileInfoList, basePath);
            }
        }
    }

    // 文件信息内部类
    public static class FileInfo {
        private String name;
        private long size;
        private long createTime;
        private String path;

        public FileInfo(String name, long size, long createTime, String path) {
            this.name = name;
            this.size = size;
            this.createTime = createTime;
            this.path = path;
        }

        // Getters
        public String getName() { return name; }
        public long getSize() { return size; }
        public long getCreateTime() { return createTime; }
        public String getPath() { return path; }
    }
}
