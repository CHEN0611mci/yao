package com.ruoyi.mall.common;

import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BindException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * 商城统一异常处理，优先于若依默认处理链。
 *
 * @author ruoyi
 */
@RestControllerAdvice
@Order(Ordered.HIGHEST_PRECEDENCE)
public class MallExceptionHandler
{
    private static final Logger log = LoggerFactory.getLogger(MallExceptionHandler.class);

    @ExceptionHandler(RateLimitException.class)
    public ResponseEntity<Result<Void>> handleRateLimit(RateLimitException e)
    {
        return ResponseEntity.status(e.getErrorCode().getHttpStatus())
                .header("Retry-After", String.valueOf(e.getRetryAfterSeconds()))
                .body(Result.failure(e.getErrorCode(), e.getMessage()));
    }

    @ExceptionHandler(BizException.class)
    public ResponseEntity<Result<Object>> handleBiz(BizException e)
    {
        log.warn("[{}] {} - {}", e.getErrorCode().getCodeText(), e.getErrorCode().getHttpStatus(), e.getMessage());
        Result<Object> body = Result.failure(e.getErrorCode(), e.getMessage(), e.getData());
        return ResponseEntity.status(e.getErrorCode().getHttpStatus()).body(body);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Result<Void>> handleMethodArgumentNotValid(MethodArgumentNotValidException e)
    {
        String message = e.getBindingResult().getFieldError() == null
                ? ErrorCode.PET_1001.getMessage()
                : e.getBindingResult().getFieldError().getDefaultMessage();
        return badRequest(message);
    }

    @ExceptionHandler(BindException.class)
    public ResponseEntity<Result<Void>> handleBind(BindException e)
    {
        String message = e.getAllErrors().isEmpty()
                ? ErrorCode.PET_1001.getMessage()
                : e.getAllErrors().get(0).getDefaultMessage();
        return badRequest(message);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Result<Void>> handleConstraint(ConstraintViolationException e)
    {
        return badRequest(e.getMessage());
    }

    @ExceptionHandler(DuplicateKeyException.class)
    public ResponseEntity<Result<Void>> handleDuplicateKey(DuplicateKeyException e)
    {
        log.warn("唯一键冲突: {}", e.getMessage());
        return ResponseEntity.status(ErrorCode.PET_1002.getHttpStatus())
                .body(Result.failure(ErrorCode.PET_1002, "数据已存在，请勿重复提交"));
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Result<Void>> handleDataAccess(DataAccessException e)
    {
        log.error("数据库操作失败", e);
        return ResponseEntity.status(ErrorCode.PET_5001.getHttpStatus())
                .body(Result.failure(ErrorCode.PET_5001));
    }

    private ResponseEntity<Result<Void>> badRequest(String message)
    {
        return ResponseEntity.status(ErrorCode.PET_1001.getHttpStatus())
                .body(Result.failure(ErrorCode.PET_1001, message));
    }
}
