package com.ruoyi.mall.common;

import java.io.Serializable;
import java.util.Collections;
import java.util.List;
import com.github.pagehelper.PageInfo;

/**
 * 统一分页结果。
 *
 * @author ruoyi
 */
public class PageResult<T> implements Serializable
{
    private static final long serialVersionUID = 1L;

    private int pageNum;
    private int pageSize;
    private long total;
    private List<T> list;

    public PageResult()
    {
    }

    public PageResult(int pageNum, int pageSize, long total, List<T> list)
    {
        this.pageNum = pageNum;
        this.pageSize = pageSize;
        this.total = total;
        this.list = list;
    }

    public static <T> PageResult<T> of(PageInfo<T> pageInfo)
    {
        List<T> list = pageInfo.getList() == null ? Collections.emptyList() : pageInfo.getList();
        return new PageResult<>(pageInfo.getPageNum(), pageInfo.getPageSize(), pageInfo.getTotal(), list);
    }

    public static <T> PageResult<T> empty(int pageNum, int pageSize)
    {
        return new PageResult<>(pageNum, pageSize, 0, Collections.emptyList());
    }

    public int getPageNum()
    {
        return pageNum;
    }

    public void setPageNum(int pageNum)
    {
        this.pageNum = pageNum;
    }

    public int getPageSize()
    {
        return pageSize;
    }

    public void setPageSize(int pageSize)
    {
        this.pageSize = pageSize;
    }

    public long getTotal()
    {
        return total;
    }

    public void setTotal(long total)
    {
        this.total = total;
    }

    public List<T> getList()
    {
        return list;
    }

    public void setList(List<T> list)
    {
        this.list = list;
    }
}
