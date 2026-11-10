-- Phase 2：12+1 城节点类型
-- 保留 start/neutral，新增王城/大营/关隘/渡口/文脉/水乡。

ALTER TABLE `slice_nodes`
  MODIFY COLUMN `node_type`
  ENUM('start','neutral','king','camp','pass','ferry','culture','water')
  NOT NULL DEFAULT 'neutral';
