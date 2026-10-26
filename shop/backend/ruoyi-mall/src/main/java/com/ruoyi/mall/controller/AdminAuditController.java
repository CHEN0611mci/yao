package com.ruoyi.mall.controller;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import com.ruoyi.mall.common.PageResult;
import com.ruoyi.mall.common.Result;
import com.ruoyi.system.domain.SysOperLog;
import com.ruoyi.system.service.ISysOperLogService;

/**
 * 后台操作审计接口：只读查询 sys_oper_log。
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/api/admin/audit-logs")
public class AdminAuditController
{
    private static final int DEFAULT_PAGE_SIZE = 10;

    private static final int MAX_PAGE_SIZE = 100;

    @Autowired
    private ISysOperLogService operLogService;

    @PreAuthorize("@ss.hasPermi('mall:audit:list')")
    @GetMapping
    public Result<PageResult<SysOperLog>> list(
            @RequestParam(value = "title", required = false) String title,
            @RequestParam(value = "operName", required = false) String operName,
            @RequestParam(value = "businessType", required = false) Integer businessType,
            @RequestParam(value = "status", required = false) Integer status,
            @RequestParam(value = "beginTime", required = false) String beginTime,
            @RequestParam(value = "endTime", required = false) String endTime,
            @RequestParam(value = "pageNum", required = false) Integer pageNum,
            @RequestParam(value = "pageSize", required = false) Integer pageSize)
    {
        SysOperLog query = new SysOperLog();
        query.setTitle(title);
        query.setOperName(operName);
        query.setBusinessType(businessType);
        query.setStatus(status);
        if (beginTime != null && !beginTime.isEmpty())
        {
            query.getParams().put("beginTime", completeTime(beginTime, " 00:00:00"));
        }
        if (endTime != null && !endTime.isEmpty())
        {
            query.getParams().put("endTime", completeTime(endTime, " 23:59:59"));
        }
        int currentPage = (pageNum == null || pageNum < 1) ? 1 : pageNum;
        int currentSize = (pageSize == null || pageSize < 1) ? DEFAULT_PAGE_SIZE : Math.min(pageSize, MAX_PAGE_SIZE);
        PageHelper.startPage(currentPage, currentSize);
        List<SysOperLog> list = operLogService.selectOperLogList(query);
        return Result.success(PageResult.of(new PageInfo<>(list)));
    }

    /**
     * 仅传日期时补齐时分秒，保证日期区间查询包含起止当天。
     */
    private String completeTime(String value, String suffix)
    {
        String trimmed = value.trim();
        return trimmed.length() == 10 ? trimmed + suffix : trimmed;
    }
}
