package cui.shibing.biz.mynas;

import cui.shibing.biz.common.CommonResult;
import cui.shibing.core.AnnotationSupportModel;
import cui.shibing.core.Attribution;
import cui.shibing.core.Event;
import cui.shibing.core.EventObj;

import java.util.ArrayList;
import java.util.List;

public class FileListManager extends AnnotationSupportModel {

    @Attribution
    private List<OneFileInfo> fileInfoList;

    @Event
    public CommonResult fileList(EventObj eventObj) {
        Long time = eventObj.getLongAttribution("time");
        Integer gt = eventObj.getIntegerAttribution("gt"); // 0:大于time，1：小于time

        fileInfoList = new ArrayList<>();
        OneFileInfo info = new OneFileInfo();
        info.setMd5("1213242423424245");
        info.setPath("http://10.42.0.1:8999/files/1213242423424245");
        info.setCreateTime(System.currentTimeMillis() / 1000);
        fileInfoList.add(info);

        OneFileInfo info2 = new OneFileInfo();
        info2.setMd5("1213242423424245");
        info2.setPath("http://10.42.0.1:8999/files/1213242423424245");
        info2.setCreateTime(System.currentTimeMillis() / 1000);
        fileInfoList.add(info2);

        return new CommonResult().success();
    }

}
