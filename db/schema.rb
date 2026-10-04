# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_07_24_143840) do
  create_schema "_heroku"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"
  enable_extension "vector"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "basket_item_candidates", force: :cascade do |t|
    t.bigint "basket_item_id", null: false
    t.bigint "candidate_id", null: false
    t.datetime "added_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["basket_item_id", "candidate_id"], name: "idx_unique_basket_item_candidate", unique: true
    t.index ["basket_item_id"], name: "index_basket_item_candidates_on_basket_item_id"
    t.index ["candidate_id"], name: "index_basket_item_candidates_on_candidate_id"
  end

  create_table "basket_items", force: :cascade do |t|
    t.bigint "basket_id", null: false
    t.bigint "agent_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "meeting_date"
    t.text "customer_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_basket_items_on_agent_id"
    t.index ["basket_id", "agent_id"], name: "index_basket_items_on_basket_id_and_agent_id", unique: true
    t.index ["basket_id"], name: "index_basket_items_on_basket_id"
    t.index ["status"], name: "index_basket_items_on_status"
  end

  create_table "baskets", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_baskets_on_customer_id", unique: true
  end

  create_table "candidate_documents", force: :cascade do |t|
    t.string "url", null: false
    t.string "file_name", null: false
    t.bigint "candidate_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_candidate_documents_on_candidate_id"
  end

  create_table "candidate_languages", force: :cascade do |t|
    t.string "code"
    t.string "level"
    t.bigint "candidate_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_candidate_languages_on_candidate_id"
  end

  create_table "candidate_mobilities", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.bigint "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_candidate_mobilities_on_candidate_id"
    t.index ["location_id"], name: "index_candidate_mobilities_on_location_id"
  end

  create_table "candidate_sectors", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.bigint "sector_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_candidate_sectors_on_candidate_id"
    t.index ["sector_id"], name: "index_candidate_sectors_on_sector_id"
  end

  create_table "candidate_skills", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.bigint "skill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "seniority"
    t.text "experience"
    t.index ["candidate_id", "skill_id"], name: "index_candidate_skills_on_candidate_id_and_skill_id", unique: true
    t.index ["candidate_id"], name: "index_candidate_skills_on_candidate_id"
    t.index ["skill_id"], name: "index_candidate_skills_on_skill_id"
  end

  create_table "candidates", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "position"
    t.string "resume_url"
    t.string "resume_file_name"
    t.bigint "users_id"
    t.bigint "agent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "publication_status", default: "extracting"
    t.datetime "discarded_at"
    t.string "gender"
    t.text "description"
    t.integer "birth_year"
    t.string "email"
    t.string "address"
    t.string "phone_number"
    t.integer "total_experience_in_years"
    t.boolean "has_driving_license"
    t.boolean "has_a_car"
    t.string "contract_type"
    t.integer "salary_expectation"
    t.string "import_status"
    t.string "availability_notice", default: -> { "now()" }
    t.text "change_motivations"
    t.boolean "ongoing_application"
    t.text "career_relevance"
    t.integer "recruitment_commission"
    t.jsonb "resume_summary", default: {}
    t.datetime "published_at"
    t.vector "job_title_embedding", limit: 1024
    t.bigint "location_id"
    t.jsonb "llm_analysis_result"
    t.string "public_token", limit: 8
    t.datetime "expiration_notified_at"
    t.datetime "expires_at"
    t.date "last_updated_at"
    t.integer "completion_percentage", default: 0, null: false
    t.index ["agent_id"], name: "index_candidates_on_agent_id"
    t.index ["discarded_at"], name: "index_candidates_on_discarded_at"
    t.index ["expires_at"], name: "index_candidates_on_expires_at"
    t.index ["job_title_embedding"], name: "index_candidates_on_job_title_embedding", opclass: :vector_cosine_ops, using: :ivfflat
    t.index ["location_id"], name: "index_candidates_on_location_id"
    t.index ["public_token"], name: "index_candidates_on_public_token", unique: true
    t.index ["publication_status", "expires_at", "expiration_notified_at"], name: "index_candidates_on_expiration_query", comment: "Optimize expiring_soon and expired scope queries"
    t.index ["publication_status"], name: "index_candidates_on_publication_status"
    t.index ["users_id"], name: "index_candidates_on_users_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.string "siren"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "company_locations", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_company_locations_on_company_id"
    t.index ["location_id"], name: "index_company_locations_on_location_id"
  end

  create_table "company_positions", force: :cascade do |t|
    t.string "title"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_company_positions_on_company_id"
  end

  create_table "company_sectors", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "sector_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_company_sectors_on_company_id"
    t.index ["sector_id"], name: "index_company_sectors_on_sector_id"
  end

  create_table "educations", force: :cascade do |t|
    t.string "title"
    t.bigint "candidate_id", null: false
    t.string "location"
    t.string "issuing_organization"
    t.integer "duration_in_months"
    t.integer "from_year"
    t.integer "from_month"
    t.integer "to_year"
    t.integer "to_month"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_educations_on_candidate_id"
  end

  create_table "embedding_caches", force: :cascade do |t|
    t.string "text_hash", null: false
    t.text "text", null: false
    t.vector "embedding", limit: 1024, null: false
    t.integer "usage_count", default: 0, null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_embedding_caches_on_created_at"
    t.index ["last_used_at"], name: "index_embedding_caches_on_last_used_at"
    t.index ["text_hash"], name: "index_embedding_caches_on_text_hash", unique: true
    t.index ["usage_count"], name: "index_embedding_caches_on_usage_count"
  end

  create_table "employments", force: :cascade do |t|
    t.string "title"
    t.bigint "candidate_id", null: false
    t.string "company"
    t.text "description"
    t.integer "duration_in_months"
    t.integer "from_year"
    t.integer "from_month"
    t.integer "to_year"
    t.integer "to_month"
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "sector"
    t.index ["candidate_id"], name: "index_employments_on_candidate_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "city"
    t.string "zip_code"
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address"
    t.index ["latitude", "longitude"], name: "index_locations_on_latitude_and_longitude"
  end

  create_table "partner_companies", force: :cascade do |t|
    t.bigint "recruitment_office_id", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_partner_companies_on_company_id"
    t.index ["recruitment_office_id", "company_id"], name: "idx_on_recruitment_office_id_company_id_17badd97cc", unique: true
    t.index ["recruitment_office_id"], name: "index_partner_companies_on_recruitment_office_id"
  end

  create_table "project_candidate_questions", force: :cascade do |t|
    t.bigint "project_candidate_id", null: false
    t.text "question"
    t.text "answer"
    t.string "kind"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_candidate_id"], name: "index_project_candidate_questions_on_project_candidate_id"
  end

  create_table "project_candidates", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "candidate_id", null: false
    t.integer "status", default: 0, null: false
    t.decimal "match_score", precision: 5, scale: 4
    t.datetime "viewed_at"
    t.datetime "interest_expressed_at"
    t.text "interest_message"
    t.jsonb "llm_analysis", default: {}
    t.string "pdf_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "agent_analysis", default: {}
    t.datetime "pushed_at"
    t.datetime "agent_validated_at"
    t.index ["candidate_id"], name: "index_project_candidates_on_candidate_id"
    t.index ["project_id", "candidate_id"], name: "index_project_candidates_on_project_id_and_candidate_id", unique: true
    t.index ["project_id"], name: "index_project_candidates_on_project_id"
  end

  create_table "project_skills", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "skill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "required", default: false, null: false
    t.integer "seniority"
    t.index ["project_id", "skill_id"], name: "index_project_skills_on_project_id_and_skill_id", unique: true
    t.index ["project_id"], name: "index_project_skills_on_project_id"
    t.index ["skill_id"], name: "index_project_skills_on_skill_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "title"
    t.string "position_name"
    t.string "contract_type"
    t.date "start_date"
    t.integer "status"
    t.boolean "alerts_enabled"
    t.bigint "customer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "location_id"
    t.text "description"
    t.integer "min_experience_years"
    t.string "education_level"
    t.jsonb "languages", default: []
    t.integer "target_salary"
    t.string "desired_availability"
    t.bigint "saved_search_id"
    t.boolean "broadcast_enabled", default: false, null: false
    t.datetime "last_email_broadcasted_at"
    t.index ["customer_id"], name: "index_projects_on_customer_id"
    t.index ["location_id"], name: "index_projects_on_location_id"
    t.index ["saved_search_id"], name: "index_projects_on_saved_search_id"
  end

  create_table "recruitment_offices", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.string "siret_number"
    t.string "vat_number"
    t.string "address"
    t.string "city"
    t.string "zip_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.bigint "location_id"
    t.index ["discarded_at"], name: "index_recruitment_offices_on_discarded_at"
    t.index ["location_id"], name: "index_recruitment_offices_on_location_id"
  end

  create_table "red_flags", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.string "slug"
    t.integer "score"
    t.text "question"
    t.text "answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "optional", default: true
    t.index ["candidate_id"], name: "index_red_flags_on_candidate_id"
  end

  create_table "referrals", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.string "email"
    t.string "company"
    t.string "position"
    t.text "description"
    t.bigint "candidate_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_referrals_on_candidate_id"
  end

  create_table "saved_search_viewed_candidates", force: :cascade do |t|
    t.bigint "saved_search_id", null: false
    t.bigint "candidate_id", null: false
    t.datetime "viewed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_saved_search_viewed_candidates_on_candidate_id"
    t.index ["saved_search_id", "candidate_id"], name: "idx_unique_saved_search_candidate", unique: true
    t.index ["saved_search_id"], name: "index_saved_search_viewed_candidates_on_saved_search_id"
  end

  create_table "saved_searches", force: :cascade do |t|
    t.string "name", null: false
    t.jsonb "criteria", default: {}, null: false
    t.bigint "customer_id", null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "email_alerts_enabled", default: false, null: false
    t.datetime "last_alert_sent_at"
    t.boolean "archived", default: false, null: false
    t.index ["archived"], name: "index_saved_searches_on_archived"
    t.index ["customer_id", "last_used_at"], name: "index_saved_searches_on_customer_id_and_last_used_at"
    t.index ["customer_id"], name: "index_saved_searches_on_customer_id"
    t.index ["email_alerts_enabled", "last_alert_sent_at"], name: "idx_on_email_alerts_enabled_last_alert_sent_at_f787f1e947"
    t.index ["email_alerts_enabled"], name: "index_saved_searches_on_email_alerts_enabled"
  end

  create_table "sectors", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "skills", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "semantic", default: []
    t.vector "embedding", limit: 1024
    t.index ["embedding"], name: "index_skills_on_embedding", opclass: :vector_cosine_ops, using: :ivfflat
    t.index ["name"], name: "index_skills_on_name", unique: true
    t.index ["slug"], name: "index_skills_on_slug", unique: true
  end

  create_table "trainings", force: :cascade do |t|
    t.string "title"
    t.integer "year"
    t.string "issuing_organization"
    t.bigint "candidate_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_trainings_on_candidate_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role"
    t.bigint "recruitment_office_id"
    t.string "first_name"
    t.string "last_name"
    t.datetime "password_set_at"
    t.datetime "invitation_sent_at"
    t.string "password_token"
    t.datetime "terms_accepted_at"
    t.datetime "discarded_at"
    t.string "phone_number"
    t.string "job_title"
    t.bigint "company_id"
    t.string "avatar_url"
    t.text "description"
    t.integer "average_completion_percentage"
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["recruitment_office_id"], name: "index_users_on_recruitment_office_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "basket_item_candidates", "basket_items"
  add_foreign_key "basket_item_candidates", "candidates"
  add_foreign_key "basket_items", "baskets"
  add_foreign_key "basket_items", "users", column: "agent_id"
  add_foreign_key "baskets", "users", column: "customer_id"
  add_foreign_key "candidate_documents", "candidates"
  add_foreign_key "candidate_languages", "candidates"
  add_foreign_key "candidate_mobilities", "candidates"
  add_foreign_key "candidate_mobilities", "locations"
  add_foreign_key "candidate_sectors", "candidates"
  add_foreign_key "candidate_sectors", "sectors"
  add_foreign_key "candidate_skills", "candidates"
  add_foreign_key "candidate_skills", "skills"
  add_foreign_key "candidates", "locations"
  add_foreign_key "candidates", "users", column: "agent_id"
  add_foreign_key "candidates", "users", column: "users_id"
  add_foreign_key "company_locations", "companies"
  add_foreign_key "company_locations", "locations"
  add_foreign_key "company_positions", "companies"
  add_foreign_key "company_sectors", "companies"
  add_foreign_key "company_sectors", "sectors"
  add_foreign_key "educations", "candidates"
  add_foreign_key "employments", "candidates"
  add_foreign_key "partner_companies", "companies"
  add_foreign_key "partner_companies", "recruitment_offices"
  add_foreign_key "project_candidate_questions", "project_candidates"
  add_foreign_key "project_candidates", "candidates"
  add_foreign_key "project_candidates", "projects"
  add_foreign_key "project_skills", "projects"
  add_foreign_key "project_skills", "skills"
  add_foreign_key "projects", "locations"
  add_foreign_key "projects", "saved_searches"
  add_foreign_key "projects", "users", column: "customer_id"
  add_foreign_key "recruitment_offices", "locations"
  add_foreign_key "red_flags", "candidates"
  add_foreign_key "referrals", "candidates"
  add_foreign_key "saved_search_viewed_candidates", "candidates"
  add_foreign_key "saved_search_viewed_candidates", "saved_searches"
  add_foreign_key "saved_searches", "users", column: "customer_id"
  add_foreign_key "trainings", "candidates"
  add_foreign_key "users", "companies"
  add_foreign_key "users", "recruitment_offices"
end
