package com.ruoyi.mall.service;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.mall.common.BizException;
import com.ruoyi.mall.common.ErrorCode;
import com.ruoyi.mall.common.ForbiddenException;
import com.ruoyi.mall.common.MallConfigService;
import com.ruoyi.mall.domain.PetAddress;
import com.ruoyi.mall.dto.AddressRequest;
import com.ruoyi.mall.mapper.PetAddressMapper;

/**
 * 收货地址服务。
 *
 * @author ruoyi
 */
@Service
public class AddressService
{
    @Autowired
    private PetAddressMapper addressMapper;

    @Autowired
    private MallConfigService configService;
    @Autowired private MemberWriteLock memberLock;

    public List<PetAddress> list(Long memberId)
    {
        return addressMapper.selectByMemberId(memberId);
    }

    public PetAddress getOwned(Long memberId, Long addressId)
    {
        PetAddress address = addressMapper.selectByIdAndMember(addressId, memberId);
        if (address == null)
        {
            throw new BizException(ErrorCode.PET_3004, "收货地址不存在或无权访问");
        }
        return address;
    }

    @Transactional(rollbackFor = Exception.class)
    public PetAddress create(Long memberId, AddressRequest request)
    {
        memberLock.acquire(memberId);
        int count = addressMapper.countByMember(memberId);
        if (count >= configService.addressMax())
        {
            throw new BizException(ErrorCode.PET_1004,
                    "最多保存" + configService.addressMax() + "个收货地址");
        }
        int isDefault = request.isDefault() != null && request.isDefault() == 1 ? 1 : 0;
        if (count == 0)
        {
            isDefault = 1;
        }
        if (isDefault == 1)
        {
            clearDefaults(memberId);
        }
        PetAddress address = new PetAddress();
        address.setMemberId(memberId);
        apply(address, request);
        address.setIsDefault(isDefault);
        addressMapper.insert(address);
        return addressMapper.selectByIdAndMember(address.getId(), memberId);
    }

    @Transactional(rollbackFor = Exception.class)
    public PetAddress update(Long memberId, Long addressId, AddressRequest request)
    {
        memberLock.acquire(memberId);
        PetAddress address = getOwned(memberId, addressId);
        apply(address, request);
        if (Integer.valueOf(1).equals(address.getIsDefault()) && Integer.valueOf(0).equals(request.isDefault()))
            throw new BizException(ErrorCode.PET_1001, "请先将其他地址设为默认地址");
        if (request.isDefault() != null)
        {
            address.setIsDefault(request.isDefault() == 1 ? 1 : 0);
            if (address.getIsDefault() == 1)
            {
                clearDefaults(memberId);
            }
        }
        addressMapper.update(address);
        return addressMapper.selectByIdAndMember(addressId, memberId);
    }

    @Transactional(rollbackFor = Exception.class)
    public void delete(Long memberId, Long addressId)
    {
        memberLock.acquire(memberId);
        PetAddress address = getOwned(memberId, addressId);
        if (addressMapper.countActiveOrderByAddress(memberId, addressId) > 0)
        {
            throw new BizException(ErrorCode.PET_1003, "该地址仍被未完成订单引用，无法删除");
        }
        addressMapper.delete(addressId, memberId);
        if (address.getIsDefault() != null && address.getIsDefault() == 1)
        {
            List<PetAddress> remains = addressMapper.selectByMemberId(memberId);
            if (!remains.isEmpty())
            {
                addressMapper.setDefault(remains.get(0).getId(), memberId);
            }
        }
    }

    @Transactional(rollbackFor = Exception.class)
    public PetAddress setDefault(Long memberId, Long addressId)
    {
        memberLock.acquire(memberId);
        getOwned(memberId, addressId);
        clearDefaults(memberId);
        addressMapper.setDefault(addressId, memberId);
        return addressMapper.selectByIdAndMember(addressId, memberId);
    }

    private void clearDefaults(Long memberId)
    {
        // The member row is already locked by every caller. Update existing PKs
        // only, avoiding range/gap locks on empty address ranges of other members.
        for (PetAddress row : addressMapper.selectByMemberId(memberId))
            if (Integer.valueOf(1).equals(row.getIsDefault()))
                addressMapper.clearDefault(memberId, row.getId());
    }

    private void apply(PetAddress address, AddressRequest request)
    {
        address.setReceiver(request.receiver().trim());
        address.setPhone(request.phone().trim());
        address.setProvince(request.province().trim());
        address.setCity(request.city().trim());
        address.setDistrict(request.district().trim());
        address.setDetail(request.detail().trim());
    }
}
