package com.ruoyi.mall.common;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.connection.RedisConnection;
import org.springframework.data.redis.core.Cursor;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.ScanOptions;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;
import com.ruoyi.common.core.redis.RedisCache;

/** Per-member session index. Runtime operations never enumerate other members' keys. */
@Component
public class MemberSessionIndex
{
    public static final String INDEX_PREFIX = "member_sessions:";
    private static final Logger log = LoggerFactory.getLogger(MemberSessionIndex.class);
    private static final int BATCH_SIZE = 256;
    private static final String EXTEND_INDEX = """
            local ttl = redis.call('PTTL', KEYS[2])
            if ttl < tonumber(ARGV[2]) then redis.call('PEXPIRE', KEYS[2], ARGV[2]) end
            return 1
            """;
    private static final DefaultRedisScript<Long> CREATE = script("""
            redis.call('SET', KEYS[1], ARGV[1], 'PX', ARGV[2])
            redis.call('HSET', KEYS[2], ARGV[3], ARGV[4])
            """ + EXTEND_INDEX);
    private static final DefaultRedisScript<Long> INDEX_EXISTING = script("""
            if redis.call('EXISTS', KEYS[1]) == 0 then return 0 end
            local remaining = redis.call('PTTL', KEYS[1])
            if remaining <= 0 then return 0 end
            redis.call('HSET', KEYS[2], ARGV[1], ARGV[2])
            if redis.call('PTTL', KEYS[2]) < remaining then
                redis.call('PEXPIRE', KEYS[2], remaining)
            end
            return 1
            """);
    private static final DefaultRedisScript<Long> REFRESH = script("""
            if redis.call('EXISTS', KEYS[1]) == 0 then return 0 end
            redis.call('PEXPIRE', KEYS[1], ARGV[2])
            redis.call('HSET', KEYS[2], ARGV[3], ARGV[4])
            """ + EXTEND_INDEX);
    private static final DefaultRedisScript<Long> REMOVE = script("""
            local removed = redis.call('DEL', KEYS[1])
            if redis.call('HGET', KEYS[2], ARGV[1]) == ARGV[2] then
                redis.call('HDEL', KEYS[2], ARGV[1])
            end
            if redis.call('HLEN', KEYS[2]) == 0 then redis.call('DEL', KEYS[2]) end
            return removed
            """);
    private static final DefaultRedisScript<Long> REMOVE_OTHERS = script("""
            local entries = redis.call('HGETALL', KEYS[1])
            local count = 0
            for i = 1, #entries, 2 do
                if entries[i+1] ~= ARGV[1] then
                    count = count + redis.call('DEL', ARGV[2] .. entries[i+1])
                    redis.call('HDEL', KEYS[1], entries[i])
                end
            end
            if redis.call('HLEN', KEYS[1]) == 0 then redis.call('DEL', KEYS[1]) end
            return count
            """);
    private static final DefaultRedisScript<Long> PRUNE = script("""
            for i = 1, #ARGV, 2 do
                if redis.call('HGET', KEYS[1], ARGV[i]) == ARGV[i+1]
                    and redis.call('EXISTS', 'member_tokens:' .. ARGV[i+1]) == 0 then
                    redis.call('HDEL', KEYS[1], ARGV[i])
                end
            end
            if redis.call('HLEN', KEYS[1]) == 0 then redis.call('DEL', KEYS[1]) end
            return 1
            """);

    @Autowired private StringRedisTemplate strings;
    @Autowired private RedisCache cache;

    private static DefaultRedisScript<Long> script(String source)
    { return new DefaultRedisScript<>(source, Long.class); }
    private static String tokenKey(String token)
    { return MemberTokenService.TOKEN_KEY_PREFIX + token; }
    private static String indexKey(Long memberId)
    { return INDEX_PREFIX + memberId; }

    @SuppressWarnings("unchecked")
    private String encode(MemberSession session)
    { return new String(cache.redisTemplate.getValueSerializer().serialize(session), StandardCharsets.UTF_8); }
    private MemberSession decode(String json)
    { return json == null ? null : (MemberSession) cache.redisTemplate.getValueSerializer().deserialize(json.getBytes(StandardCharsets.UTF_8)); }

    public void create(MemberSession session, long ttlMillis)
    {
        strings.execute(CREATE, List.of(tokenKey(session.getToken()), indexKey(session.getMemberId())),
                encode(session), String.valueOf(ttlMillis), MemberTokenService.sessionId(session), session.getToken());
    }
    public MemberSession read(String token)
    {
        if (token == null || !token.matches("[a-fA-F0-9]{32}")) return null;
        MemberSession session = decode(strings.opsForValue().get(tokenKey(token)));
        return session != null && token.equals(session.getToken()) ? session : null;
    }
    public boolean refresh(MemberSession session, long ttlMillis)
    {
        return Long.valueOf(1).equals(strings.execute(REFRESH,
                List.of(tokenKey(session.getToken()), indexKey(session.getMemberId())),
                "", String.valueOf(ttlMillis), MemberTokenService.sessionId(session), session.getToken()));
    }
    public boolean remove(MemberSession session)
    {
        return Long.valueOf(1).equals(strings.execute(REMOVE,
                List.of(tokenKey(session.getToken()), indexKey(session.getMemberId())),
                MemberTokenService.sessionId(session), session.getToken()));
    }
    public int removeOthers(Long memberId, String keepToken)
    {
        Long count = strings.execute(REMOVE_OTHERS, List.of(indexKey(memberId)),
                keepToken == null ? "" : keepToken, MemberTokenService.TOKEN_KEY_PREFIX);
        return count == null ? 0 : Math.toIntExact(count);
    }
    public MemberSession owned(Long memberId, String id)
    {
        Object token = strings.opsForHash().get(indexKey(memberId), id);
        MemberSession session = token == null ? null : read(token.toString());
        return session != null && memberId.equals(session.getMemberId())
                && id.equals(MemberTokenService.sessionId(session)) ? session : null;
    }

    public record ActiveSession(MemberSession session, long ttlMillis) { }
    public List<ActiveSession> active(Long memberId)
    {
        List<Map.Entry<Object, Object>> entries = new ArrayList<>(strings.opsForHash().entries(indexKey(memberId)).entrySet());
        List<ActiveSession> result = new ArrayList<>();
        for (int start = 0; start < entries.size(); start += BATCH_SIZE)
        {
            List<Map.Entry<Object, Object>> batch = entries.subList(start, Math.min(start + BATCH_SIZE, entries.size()));
            List<Object> values = strings.executePipelined((RedisCallback<Object>) connection -> {
                for (var entry : batch)
                {
                    byte[] key = tokenKey(entry.getValue().toString()).getBytes(StandardCharsets.UTF_8);
                    connection.stringCommands().get(key);
                    connection.keyCommands().pTtl(key);
                }
                return null;
            });
            List<String> expired = new ArrayList<>();
            for (int i = 0; i < batch.size(); i++)
            {
                var entry = batch.get(i);
                MemberSession session = decode((String) values.get(i * 2));
                long ttl = ((Number) values.get(i * 2 + 1)).longValue();
                if (session != null && ttl > 0 && memberId.equals(session.getMemberId())
                        && entry.getKey().equals(MemberTokenService.sessionId(session)))
                    result.add(new ActiveSession(session, ttl));
                else if (session == null)
                { expired.add(entry.getKey().toString()); expired.add(entry.getValue().toString()); }
            }
            if (!expired.isEmpty()) strings.execute(PRUNE, List.of(indexKey(memberId)), expired.toArray());
        }
        return result;
    }

    /** Runs before this bean is available to HTTP handlers. Preserves token values and TTLs. */
    @PostConstruct
    public void migrateExistingSessions() throws Exception
    {
        long indexed = 0;
        try (RedisConnection connection = strings.getConnectionFactory().getConnection();
                Cursor<byte[]> cursor = connection.keyCommands().scan(ScanOptions.scanOptions()
                        .match(MemberTokenService.TOKEN_KEY_PREFIX + "*").count(BATCH_SIZE).build()))
        {
            List<String> batch = new ArrayList<>(BATCH_SIZE);
            while (cursor.hasNext())
            {
                batch.add(new String(cursor.next(), StandardCharsets.UTF_8));
                if (batch.size() == BATCH_SIZE) { indexed += migrateBatch(batch); batch.clear(); }
            }
            indexed += migrateBatch(batch);
        }
        log.info("Member session index ready; indexed {} existing sessions with incremental SCAN", indexed);
    }
    private long migrateBatch(List<String> keys)
    {
        if (keys.isEmpty()) return 0;
        List<String> values = strings.opsForValue().multiGet(keys);
        long count = 0;
        for (int i = 0; i < keys.size(); i++)
        {
            MemberSession session = decode(values.get(i));
            if (session == null || session.getMemberId() == null || session.getToken() == null
                    || !keys.get(i).equals(tokenKey(session.getToken()))) continue;
            Long added = strings.execute(INDEX_EXISTING, List.of(keys.get(i), indexKey(session.getMemberId())),
                    MemberTokenService.sessionId(session), session.getToken());
            if (Long.valueOf(1).equals(added)) count++;
        }
        return count;
    }
}
