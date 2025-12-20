package com.iot.ingestion.exception;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.bind.support.WebExchangeBindException;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Global exception handler for REST endpoints.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /**
     * Handle validation errors.
     */
    @ExceptionHandler(WebExchangeBindException.class)
    public Mono<ResponseEntity<ErrorResponse>> handleValidationException(
            WebExchangeBindException ex, ServerWebExchange exchange) {
        
        List<String> details = ex.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .collect(Collectors.toList());

        String path = exchange.getRequest().getPath().value();
        
        log.warn("Validation failed for {}: {}", path, details);

        ErrorResponse response = ErrorResponse.of(
                HttpStatus.BAD_REQUEST.value(),
                "Validation Failed",
                "Request validation failed",
                path,
                details
        );

        return Mono.just(ResponseEntity.badRequest().body(response));
    }

    /**
     * Handle illegal argument exceptions (e.g., unknown enum values).
     */
    @ExceptionHandler(IllegalArgumentException.class)
    public Mono<ResponseEntity<ErrorResponse>> handleIllegalArgument(
            IllegalArgumentException ex, ServerWebExchange exchange) {
        
        String path = exchange.getRequest().getPath().value();
        
        log.warn("Invalid argument for {}: {}", path, ex.getMessage());

        ErrorResponse response = ErrorResponse.of(
                HttpStatus.BAD_REQUEST.value(),
                "Bad Request",
                ex.getMessage(),
                path
        );

        return Mono.just(ResponseEntity.badRequest().body(response));
    }

    /**
     * Handle JSON parsing errors.
     */
    @ExceptionHandler(org.springframework.core.codec.DecodingException.class)
    public Mono<ResponseEntity<ErrorResponse>> handleDecodingException(
            org.springframework.core.codec.DecodingException ex, ServerWebExchange exchange) {
        
        String path = exchange.getRequest().getPath().value();
        String message = "Invalid JSON format";
        
        // Try to extract more specific error
        Throwable cause = ex.getCause();
        if (cause != null) {
            message = cause.getMessage();
        }
        
        log.warn("JSON decoding failed for {}: {}", path, message);

        ErrorResponse response = ErrorResponse.of(
                HttpStatus.BAD_REQUEST.value(),
                "Invalid Request Body",
                message,
                path
        );

        return Mono.just(ResponseEntity.badRequest().body(response));
    }

    /**
     * Handle all other exceptions.
     */
    @ExceptionHandler(Exception.class)
    public Mono<ResponseEntity<ErrorResponse>> handleGenericException(
            Exception ex, ServerWebExchange exchange) {
        
        String path = exchange.getRequest().getPath().value();
        
        log.error("Unexpected error for {}: {}", path, ex.getMessage(), ex);

        ErrorResponse response = ErrorResponse.of(
                HttpStatus.INTERNAL_SERVER_ERROR.value(),
                "Internal Server Error",
                "An unexpected error occurred",
                path
        );

        return Mono.just(ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response));
    }
}
