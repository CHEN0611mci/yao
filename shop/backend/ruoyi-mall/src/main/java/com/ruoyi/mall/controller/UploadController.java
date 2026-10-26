package com.ruoyi.mall.controller;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.utils.file.FileUploadUtils;
import com.ruoyi.common.utils.file.FileUtils;
import com.ruoyi.mall.common.Result;

/**
 * 商城图片上传接口。
 *
 * <p>后台账号使用 /api/upload/image（若依 JWT），会员使用 /api/member/upload/image（会员 Token）。</p>
 *
 * @author ruoyi
 */
@RestController
public class UploadController
{
    @PostMapping("/api/upload/image")
    public Result<Map<String, Object>> uploadForAdmin(MultipartFile file) throws IOException
    {
        return Result.success("上传成功", store(file));
    }

    @PostMapping("/api/member/upload/image")
    public Result<Map<String, Object>> uploadForMember(MultipartFile file) throws IOException
    {
        return Result.success("上传成功", store(file));
    }

    private Map<String, Object> store(MultipartFile file) throws IOException
    {
        if (file == null || file.isEmpty())
        {
            throw new IllegalArgumentException("上传文件不能为空");
        }
        String fileName = FileUploadUtils.upload(RuoYiConfig.getUploadPath(), file);
        Map<String, Object> data = new LinkedHashMap<>();
        // fileName 形如 /profile/upload/2026/10/19/xxx.jpg，前端可直接作为相对地址使用
        data.put("url", fileName);
        data.put("fileName", fileName);
        data.put("newFileName", FileUtils.getName(fileName));
        data.put("originalFilename", file.getOriginalFilename());
        return data;
    }
}
