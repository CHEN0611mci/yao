package com.ruoyi.mall.controller;

import java.sql.Connection;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.connection.RedisConnection;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.redis.RedisCache;

/** Readiness must include the dependencies used by registration and catalog queries. */
@RestController
public class HealthController
{
    @Autowired private DataSource dataSource;
    @Autowired private RedisCache redisCache;

    @GetMapping("/api/health")
    public ResponseEntity<Map<String, Object>> health()
    {
        Map<String, String> checks = new LinkedHashMap<>();
        try (Connection connection = dataSource.getConnection();
             var statement = connection.prepareStatement("SELECT COUNT(*) FROM pet_category");
             var result = statement.executeQuery())
        {
            checks.put("database", result.next() ? "UP" : "DOWN");
        }
        catch (Exception e) { checks.put("database", "DOWN"); }
        try (RedisConnection connection = redisCache.redisTemplate.getConnectionFactory().getConnection())
        {
            checks.put("redis", "PONG".equals(connection.ping()) ? "UP" : "DOWN");
        }
        catch (Exception e) { checks.put("redis", "DOWN"); }
        boolean ready = checks.values().stream().allMatch("UP"::equals);
        return ResponseEntity.status(ready ? 200 : 503).body(Map.of(
                "code", ready ? 200 : 503, "message", ready ? "商城服务已就绪" : "数据库或缓存未就绪，请检查后端依赖",
                "data", checks));
    }
}
