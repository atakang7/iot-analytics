"""
Alert Evaluation Pipeline

Evaluates rules against telemetry data to generate alerts.
No infrastructure dependencies - pure data processing.
"""

from dataclasses import dataclass
from typing import Callable, Optional, Any
from pipelines.base import Pipeline, PipelineResult, Alert, Severity


@dataclass
class Rule:
    """
    A single alert rule.
    
    Example:
        Rule(
            name="high_temperature",
            condition=lambda d: d.get("metric_type") == "temperature" and d.get("value", 0) > 100,
            message="Temperature exceeds 100°C",
            severity=Severity.WARNING
        )
    """
    name: str
    condition: Callable[[dict], bool]
    message: str
    severity: Severity = Severity.WARNING
    enabled: bool = True
    
    def evaluate(self, data: dict) -> Optional[Alert]:
        """Evaluate rule against data, return Alert if triggered."""
        if not self.enabled:
            return None
        
        try:
            if self.condition(data):
                return Alert(
                    name=self.name,
                    message=self.message,
                    severity=self.severity,
                    source=data.get("device_id", "unknown"),
                    value=data.get("value"),
                )
        except Exception:
            # Rule evaluation failed, don't alert
            pass
        
        return None


class AlertEvaluator(Pipeline):
    """
    Evaluates a set of rules against incoming data.
    
    Rules are simple predicates - if the condition is true, an alert fires.
    
    Example:
        evaluator = AlertEvaluator()
        
        # Add rules
        evaluator.add_rule(Rule(
            name="high_temp",
            condition=lambda d: d.get("value", 0) > 100,
            message="High temperature detected",
            severity=Severity.WARNING
        ))
        
        evaluator.add_threshold_rule(
            name="critical_pressure",
            metric_type="pressure",
            threshold=500,
            severity=Severity.CRITICAL
        )
        
        # Process data
        result = evaluator.process({"device_id": "s1", "metric_type": "temperature", "value": 150})
        print(result.alerts)  # [Alert(name="high_temp", ...)]
    """
    
    def __init__(self, rules: Optional[list[Rule]] = None):
        self.rules: list[Rule] = rules or []
    
    @property
    def name(self) -> str:
        return "alert_evaluator"
    
    def add_rule(self, rule: Rule):
        """Add a custom rule."""
        self.rules.append(rule)
    
    def add_threshold_rule(
        self,
        name: str,
        metric_type: str,
        threshold: float,
        operator: str = ">",
        severity: Severity = Severity.WARNING,
        message: Optional[str] = None
    ):
        """
        Convenience method to add a threshold-based rule.
        
        Args:
            name: Rule name
            metric_type: Type of metric to check (e.g., "temperature")
            threshold: Threshold value
            operator: One of ">", ">=", "<", "<=", "=="
            severity: Alert severity
            message: Custom message (auto-generated if None)
        """
        ops = {
            ">": lambda v, t: v > t,
            ">=": lambda v, t: v >= t,
            "<": lambda v, t: v < t,
            "<=": lambda v, t: v <= t,
            "==": lambda v, t: v == t,
        }
        
        if operator not in ops:
            raise ValueError(f"Unknown operator: {operator}")
        
        op_func = ops[operator]
        msg = message or f"{metric_type} {operator} {threshold}"
        
        rule = Rule(
            name=name,
            condition=lambda d, mt=metric_type, op=op_func, th=threshold: (
                d.get("metric_type") == mt and op(float(d.get("value", 0)), th)
            ),
            message=msg,
            severity=severity
        )
        self.rules.append(rule)
    
    def add_range_rule(
        self,
        name: str,
        metric_type: str,
        min_value: float,
        max_value: float,
        severity: Severity = Severity.WARNING,
        message: Optional[str] = None
    ):
        """
        Add a rule that fires when value is outside a range.
        
        Args:
            name: Rule name
            metric_type: Type of metric to check
            min_value: Minimum acceptable value
            max_value: Maximum acceptable value
            severity: Alert severity
            message: Custom message
        """
        msg = message or f"{metric_type} outside range [{min_value}, {max_value}]"
        
        rule = Rule(
            name=name,
            condition=lambda d, mt=metric_type, lo=min_value, hi=max_value: (
                d.get("metric_type") == mt and 
                (float(d.get("value", 0)) < lo or float(d.get("value", 0)) > hi)
            ),
            message=msg,
            severity=severity
        )
        self.rules.append(rule)
    
    def process(self, data: dict) -> PipelineResult:
        alerts = []
        triggered_rules = []
        
        for rule in self.rules:
            alert = rule.evaluate(data)
            if alert:
                alerts.append(alert)
                triggered_rules.append(rule.name)
        
        result_data = {
            "device_id": data.get("device_id", "unknown"),
            "metric_type": data.get("metric_type", "unknown"),
            "value": data.get("value"),
            "rules_evaluated": len(self.rules),
            "rules_triggered": triggered_rules,
        }
        
        return PipelineResult(
            pipeline=self.name,
            data=result_data,
            alerts=alerts
        )
    
    def enable_rule(self, name: str):
        """Enable a rule by name."""
        for rule in self.rules:
            if rule.name == name:
                rule.enabled = True
                return
    
    def disable_rule(self, name: str):
        """Disable a rule by name."""
        for rule in self.rules:
            if rule.name == name:
                rule.enabled = False
                return
    
    def remove_rule(self, name: str):
        """Remove a rule by name."""
        self.rules = [r for r in self.rules if r.name != name]
