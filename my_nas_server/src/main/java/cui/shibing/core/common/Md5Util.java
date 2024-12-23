package cui.shibing.core.common;

import java.io.File;
import java.io.RandomAccessFile;
import java.security.MessageDigest;

public class Md5Util {
    private static final int DEFAULT_SAMPLE_SIZE = 20 * 1024; // 默认20KB
    private static final int SAMPLE_COUNT = 5; // 采样次数

    public static String getPartialContentMd5(String filePath) {
        return getPartialContentMd5(filePath, DEFAULT_SAMPLE_SIZE);
    }

    public static String getPartialContentMd5(String filePath, int sampleSizeKB) {
        if (sampleSizeKB <= 0) {
            throw new IllegalArgumentException("采样大小必须大于0KB");
        }

        File file = new File(filePath);
        if (!file.exists()) {
            throw new RuntimeException("文件不存在: " + filePath);
        }

        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            long fileSize = file.length();
            int sampleBytes = sampleSizeKB * 1024;

            // 如果文件小于采样大小的5倍，直接读取整个文件
            if (fileSize <= SAMPLE_COUNT * sampleBytes) {
                try (RandomAccessFile raf = new RandomAccessFile(file, "r")) {
                    byte[] buffer = new byte[(int) fileSize];
                    raf.read(buffer);
                    md.update(buffer);
                }
            } else {
                // 计算每个采样点之间的间隔
                long interval = (fileSize - sampleBytes) / (SAMPLE_COUNT - 1);
                
                try (RandomAccessFile raf = new RandomAccessFile(file, "r")) {
                    byte[] buffer = new byte[sampleBytes];
                    
                    // 进行5次采样
                    for (int i = 0; i < SAMPLE_COUNT; i++) {
                        // 计算当前采样点的位置
                        long position = i * interval;
                        raf.seek(position);
                        
                        // 读取采样数据
                        int bytesRead = raf.read(buffer);
                        if (bytesRead > 0) {
                            // 如果读取的数据小于buffer大小，只更新实际读取的部分
                            if (bytesRead < sampleBytes) {
                                byte[] actualData = new byte[bytesRead];
                                System.arraycopy(buffer, 0, actualData, 0, bytesRead);
                                md.update(actualData);
                            } else {
                                md.update(buffer);
                            }
                        }
                    }
                }
            }

            // 转换MD5为十六进制字符串
            byte[] md5Bytes = md.digest();
            StringBuilder sb = new StringBuilder();
            for (byte b : md5Bytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("计算MD5失败", e);
        }
    }
}
