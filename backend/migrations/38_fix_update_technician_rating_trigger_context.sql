-- Fix trigger-function context collision for update_technician_rating().
-- The same trigger function name is used by both:
-- 1) jobs.on_job_rated (expects NEW.customer_rating / NEW.technician_id)
-- 2) reviews.on_review_created (expects NEW.reviewee_id)
-- This migration makes the function context-aware and re-creates the jobs trigger
-- to fire only on customer_rating updates.

CREATE OR REPLACE FUNCTION public.update_technician_rating()
RETURNS TRIGGER AS $$
DECLARE
    v_tech_id UUID;
    v_avg_rating NUMERIC;
    v_reviews_count INTEGER;
BEGIN
    -- Reviews path
    IF TG_TABLE_NAME = 'reviews' THEN
        v_tech_id := NEW.reviewee_id;
        IF v_tech_id IS NULL THEN
            RETURN NEW;
        END IF;

        SELECT COALESCE(AVG(rating), 5.0)
        INTO v_avg_rating
        FROM public.reviews
        WHERE reviewee_id = v_tech_id;

        UPDATE public.users
        SET rating = ROUND(v_avg_rating::numeric, 2)
        WHERE id = v_tech_id;

        RETURN NEW;
    END IF;

    -- Jobs path
    IF TG_TABLE_NAME = 'jobs' THEN
        IF TG_OP = 'DELETE' THEN
            v_tech_id := OLD.technician_id;
        ELSE
            v_tech_id := NEW.technician_id;
        END IF;

        IF v_tech_id IS NULL THEN
            RETURN NEW;
        END IF;

        -- Skip no-op updates on jobs.
        IF TG_OP = 'UPDATE' AND OLD.customer_rating IS NOT DISTINCT FROM NEW.customer_rating THEN
            RETURN NEW;
        END IF;

        SELECT
            COALESCE(AVG(customer_rating), 5.0),
            COUNT(*)
        INTO
            v_avg_rating,
            v_reviews_count
        FROM public.jobs
        WHERE technician_id = v_tech_id
          AND customer_rating IS NOT NULL;

        UPDATE public.users
        SET
            rating = ROUND(v_avg_rating::numeric, 2),
            reviews_count = v_reviews_count
        WHERE id = v_tech_id;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_job_rated ON public.jobs;
CREATE TRIGGER on_job_rated
AFTER UPDATE OF customer_rating ON public.jobs
FOR EACH ROW
EXECUTE FUNCTION public.update_technician_rating();
