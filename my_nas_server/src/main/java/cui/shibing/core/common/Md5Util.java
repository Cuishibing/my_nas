package cui.shibing.core.common;

import java.io.File;
import java.io.RandomAccessFile;
import java.security.MessageDigest;

public class Md5Util {
    private static final int DEFAULT_SAMPLE_SIZE = 20 * 1024; // 默认20KB

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

            // 如果文件小于2倍采样大小，直接读取整个文件
            if (fileSize <= 2 * sampleBytes) {
                try (RandomAccessFile raf = new RandomAccessFile(file, "r")) {
                    byte[] buffer = new byte[(int) fileSize];
                    raf.read(buffer);
                    md.update(buffer);
                }
            } else {
                // 读取前面的采样数据
                try (RandomAccessFile raf = new RandomAccessFile(file, "r")) {
                    byte[] headerBuffer = new byte[sampleBytes];
                    raf.read(headerBuffer);
                    md.update(headerBuffer);

                    // 读取后面的采样数据
                    raf.seek(fileSize - sampleBytes);
                    byte[] tailBuffer = new byte[sampleBytes];
                    raf.read(tailBuffer);
                    md.update(tailBuffer);
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
