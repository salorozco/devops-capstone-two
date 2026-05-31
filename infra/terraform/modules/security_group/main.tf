resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_security_group_rule" "ingress_cidr" {
  for_each = var.ingress_cidr_rules

  type              = "ingress"
  security_group_id = aws_security_group.this.id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}

resource "aws_security_group_rule" "ingress_self" {
  for_each = var.ingress_self_rules

  type              = "ingress"
  security_group_id = aws_security_group.this.id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  self              = true
}

resource "aws_security_group_rule" "ingress_source_security_group" {
  for_each = var.ingress_source_security_group_rules

  type                     = "ingress"
  security_group_id        = aws_security_group.this.id
  description              = each.value.description
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.source_security_group_id
}

resource "aws_security_group_rule" "egress_cidr" {
  for_each = var.egress_cidr_rules

  type              = "egress"
  security_group_id = aws_security_group.this.id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}
