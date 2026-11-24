-- ============================================================================
-- QUILLORA DATABASE SCHEMA - VERSION 1 (17 TABLES)
-- ============================================================================

-- 1. Bảng users (Gộp 4 vai trò: READER, WRITER, MOD, SUPER_ADMIN)
CREATE TABLE users (
                       id BIGSERIAL PRIMARY KEY,
                       email VARCHAR(255) NOT NULL UNIQUE,
                       password_hash VARCHAR(255) NOT NULL,
                       full_name VARCHAR(255),
                       pen_name VARCHAR(100) UNIQUE,
                       bio TEXT,
                       avatar_file_id VARCHAR(100),
                       role VARCHAR(30) NOT NULL,
                       status VARCHAR(30) NOT NULL,
                       ban_reason TEXT,
                       ban_until TIMESTAMP,
                       token_version INT NOT NULL DEFAULT 0,
                       wallet_balance BIGINT NOT NULL DEFAULT 0,
                       revenue_balance BIGINT NOT NULL DEFAULT 0,
                       policy_version VARCHAR(50),
                       consent_accepted_at TIMESTAMP,
                       email_verified_at TIMESTAMP,
                       age_confirmed_at TIMESTAMP,
                       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                       updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                       CONSTRAINT chk_users_balances_non_negative CHECK (wallet_balance >= 0 AND revenue_balance >= 0)
);

-- 2. Bảng categories (Thể loại truyện)
CREATE TABLE categories (
                            id BIGSERIAL PRIMARY KEY,
                            name VARCHAR(100) NOT NULL UNIQUE,
                            slug VARCHAR(120) NOT NULL UNIQUE,
                            description TEXT,
                            is_active BOOLEAN NOT NULL DEFAULT TRUE,
                            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Bảng stories (Thông tin bộ truyện)
CREATE TABLE stories (
                         id BIGSERIAL PRIMARY KEY,
                         writer_id BIGINT NOT NULL REFERENCES users(id),
                         title VARCHAR(255) NOT NULL,
                         slug VARCHAR(280) NOT NULL UNIQUE,
                         description TEXT,
                         cover_image_file_id VARCHAR(100),
                         status VARCHAR(30) NOT NULL,
                         review_note TEXT,
                         reviewed_by BIGINT REFERENCES users(id),
                         reviewed_at TIMESTAMP,
                         published_at TIMESTAMP,
                         is_completed BOOLEAN NOT NULL DEFAULT FALSE,
                         view_count BIGINT NOT NULL DEFAULT 0,
                         avg_rating DOUBLE PRECISION NOT NULL DEFAULT 0.0,
                         created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                         updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_stories_status_published ON stories(status, published_at);
CREATE INDEX idx_stories_title ON stories(title);

-- 4. Bảng trung gian story_categories (N-N giữa stories và categories)
CREATE TABLE story_categories (
                                  story_id BIGINT NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
                                  category_id BIGINT NOT NULL REFERENCES categories(id),
                                  PRIMARY KEY (story_id, category_id)
);

-- 5. Bảng chapters (Chương truyện & kết quả AI kiểm duyệt)
CREATE TABLE chapters (
                          id BIGSERIAL PRIMARY KEY,
                          story_id BIGINT NOT NULL REFERENCES stories(id),
                          chapter_number INT NOT NULL,
                          title VARCHAR(255) NOT NULL,
                          content TEXT NOT NULL,
                          word_count INT NOT NULL DEFAULT 0,
                          is_free BOOLEAN NOT NULL DEFAULT TRUE,
                          price BIGINT NOT NULL DEFAULT 0 CHECK (price >= 0),
                          status VARCHAR(30) NOT NULL,
                          ai_suggested_rating VARCHAR(20),
                          ai_is_flagged BOOLEAN NOT NULL DEFAULT FALSE,
                          ai_highlights JSONB,
                          ai_scanned_paragraphs JSONB,
                          ai_scanned_at TIMESTAMP,
                          ai_degraded BOOLEAN NOT NULL DEFAULT FALSE,
                          review_note TEXT,
                          reviewed_by BIGINT REFERENCES users(id),
                          published_at TIMESTAMP,
                          ai_job_id UUID,
                          content_hash VARCHAR(64),
                          ai_scan_started_at TIMESTAMP,
                          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                          CONSTRAINT uq_chapters_story_number UNIQUE (story_id, chapter_number)
);
CREATE INDEX idx_chapters_story_status ON chapters(story_id, status);
CREATE INDEX idx_chapters_status_scan_started ON chapters(status, ai_scan_started_at);

-- 6. Bảng chapter_purchases (Quyền sở hữu chương đã mua)
CREATE TABLE chapter_purchases (
                                   id BIGSERIAL PRIMARY KEY,
                                   reader_id BIGINT NOT NULL REFERENCES users(id),
                                   chapter_id BIGINT NOT NULL REFERENCES chapters(id),
                                   price_paid BIGINT NOT NULL CHECK (price_paid >= 0),
                                   revenue_share_percent INT NOT NULL,
                                   created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                   updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                   CONSTRAINT uq_chapter_purchases_reader_chapter UNIQUE (reader_id, chapter_id)
);

-- 7. Bảng bookmarks (Tủ sách yêu thích & vị trí đọc dở)
CREATE TABLE bookmarks (
                           id BIGSERIAL PRIMARY KEY,
                           reader_id BIGINT NOT NULL REFERENCES users(id),
                           story_id BIGINT NOT NULL REFERENCES stories(id),
                           current_chapter_id BIGINT REFERENCES chapters(id),
                           created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                           updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                           CONSTRAINT uq_bookmarks_reader_story UNIQUE (reader_id, story_id)
);

-- 8. Bảng reviews (Đánh giá sao 1-5 & bình luận)
CREATE TABLE reviews (
                         id BIGSERIAL PRIMARY KEY,
                         reader_id BIGINT NOT NULL REFERENCES users(id),
                         story_id BIGINT NOT NULL REFERENCES stories(id),
                         rating INT CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5)),
                         content TEXT NOT NULL,
                         status VARCHAR(30) NOT NULL,
                         created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                         updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_reviews_story_created ON reviews(story_id, created_at);

-- 9. Bảng transactions (Lịch sử dòng tiền Độc giả)
CREATE TABLE transactions (
                              id BIGSERIAL PRIMARY KEY,
                              transaction_code VARCHAR(50) NOT NULL UNIQUE,
                              reader_id BIGINT NOT NULL REFERENCES users(id),
                              type VARCHAR(30) NOT NULL,
                              amount BIGINT NOT NULL CHECK (amount >= 0),
                              payment_method VARCHAR(50),
                              reference_id BIGINT,
                              status VARCHAR(30) NOT NULL,
                              gateway_transaction_id BIGINT UNIQUE,
                              failure_reason VARCHAR(255),
                              created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                              updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_transactions_reader_created ON transactions(reader_id, created_at);
CREATE INDEX idx_transactions_status_created ON transactions(status, created_at);

-- 10. Bảng withdrawal_requests (Yêu cầu rút tiền của Tác giả)
CREATE TABLE withdrawal_requests (
                                     id BIGSERIAL PRIMARY KEY,
                                     writer_id BIGINT NOT NULL REFERENCES users(id),
                                     amount_xu BIGINT NOT NULL CHECK (amount_xu > 0),
                                     amount_vnd BIGINT NOT NULL CHECK (amount_vnd > 0),
                                     bank_name VARCHAR(100) NOT NULL,
                                     account_number VARCHAR(50) NOT NULL,
                                     account_name VARCHAR(150),
                                     status VARCHAR(30) NOT NULL,
                                     reject_reason TEXT,
                                     processed_by BIGINT REFERENCES users(id),
                                     created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                     updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_withdrawal_writer_status ON withdrawal_requests(writer_id, status);

-- 11. Bảng system_configs (Cấu hình động hệ thống)
CREATE TABLE system_configs (
                                config_key VARCHAR(100) PRIMARY KEY,
                                config_value VARCHAR(255) NOT NULL,
                                updated_by BIGINT REFERENCES users(id),
                                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Giá trị mặc định tỷ lệ chia doanh thu cho tác giả (70%)
INSERT INTO system_configs (config_key, config_value)
VALUES ('AUTHOR_REVENUE_SHARE_PERCENT', '70');

-- 12. Bảng notifications (Thông báo hệ thống)
CREATE TABLE notifications (
                               id BIGSERIAL PRIMARY KEY,
                               user_id BIGINT NOT NULL REFERENCES users(id),
                               title VARCHAR(255) NOT NULL,
                               message TEXT NOT NULL,
                               is_read BOOLEAN NOT NULL DEFAULT FALSE,
                               reference_url VARCHAR(255),
                               created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                               updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_notifications_user_read ON notifications(user_id, is_read);

-- 13. Bảng ai_feedback_logs (Human-in-the-loop phản hồi AI)
CREATE TABLE ai_feedback_logs (
                                  id BIGSERIAL PRIMARY KEY,
                                  chapter_id BIGINT NOT NULL REFERENCES chapters(id),
                                  paragraph_text TEXT NOT NULL,
                                  ai_category VARCHAR(50) NOT NULL,
                                  ai_severity INT NOT NULL,
                                  admin_action VARCHAR(30) NOT NULL,
                                  admin_id BIGINT NOT NULL REFERENCES users(id),
                                  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_ai_feedback_chapter ON ai_feedback_logs(chapter_id);

-- 14. Bảng audit_logs (Nhật ký thao tác nhạy cảm của Admin - chỉ thêm/đọc)
CREATE TABLE audit_logs (
                            id BIGSERIAL PRIMARY KEY,
                            admin_id BIGINT NOT NULL REFERENCES users(id),
                            action VARCHAR(100) NOT NULL,
                            target_type VARCHAR(50) NOT NULL,
                            target_id BIGINT,
                            details TEXT,
                            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);

-- 15. Bảng auth_tokens (Refresh token xoay vòng, reset password, verify email)
CREATE TABLE auth_tokens (
                             id BIGSERIAL PRIMARY KEY,
                             user_id BIGINT NOT NULL REFERENCES users(id),
                             token_hash VARCHAR(64) NOT NULL UNIQUE,
                             type VARCHAR(30) NOT NULL,
                             family_id UUID,
                             expires_at TIMESTAMP NOT NULL,
                             used_at TIMESTAMP,
                             revoked_at TIMESTAMP,
                             created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                             updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_auth_tokens_user_type ON auth_tokens(user_id, type);
CREATE INDEX idx_auth_tokens_family ON auth_tokens(family_id);

-- 16. Bảng consent_logs (Nhật ký đồng ý xử lý dữ liệu cá nhân - chỉ thêm)
CREATE TABLE consent_logs (
                              id BIGSERIAL PRIMARY KEY,
                              user_id BIGINT NOT NULL REFERENCES users(id),
                              purpose VARCHAR(50) NOT NULL,
                              policy_version VARCHAR(50) NOT NULL,
                              granted BOOLEAN NOT NULL,
                              method VARCHAR(50) NOT NULL,
                              created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                              updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_consent_logs_user_purpose_created ON consent_logs(user_id, purpose, created_at);

-- 17. Bảng data_subject_requests (Yêu cầu thực hiện quyền của chủ thể dữ liệu)
CREATE TABLE data_subject_requests (
                                       id BIGSERIAL PRIMARY KEY,
                                       user_id BIGINT REFERENCES users(id),
                                       contact_email VARCHAR(255) NOT NULL,
                                       type VARCHAR(30) NOT NULL,
                                       status VARCHAR(30) NOT NULL,
                                       received_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       ack_due_at TIMESTAMP NOT NULL,
                                       due_at TIMESTAMP NOT NULL,
                                       extended BOOLEAN NOT NULL DEFAULT FALSE,
                                       extension_reason TEXT,
                                       handled_by BIGINT REFERENCES users(id),
                                       note TEXT,
                                       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                       updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_dsr_status_due ON data_subject_requests(status, due_at);