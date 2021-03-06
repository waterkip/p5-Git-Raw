MODULE = Git::Raw			PACKAGE = Git::Raw::Branch

BOOT:
{
	AV *isa = get_av("Git::Raw::Branch::ISA", 1);
	av_push(isa, newSVpv("Git::Raw::Reference", 0));
}

SV *
create(class, repo, name, target)
	SV *class
	SV *repo
	SV *name
	SV *target

	PREINIT:
		int rc;

		Commit obj;
		Reference ref;
		Repository repo_ptr;

	INIT:
		obj = (Commit) git_sv_to_obj(target);

	CODE:
		repo_ptr = GIT_SV_TO_PTR(Repository, repo);

		rc = git_branch_create(
			&ref, repo_ptr -> repository,
			SvPVbyte_nolen(name), obj, 0
		);

		git_check_error(rc);

		GIT_NEW_OBJ_WITH_MAGIC(
			RETVAL, SvPVbyte_nolen(class), ref, SvRV(repo)
		);

	OUTPUT: RETVAL

SV *
lookup(class, repo, name, is_local)
	SV *class
	SV *repo
	SV *name
	bool is_local

	PREINIT:
		int rc;
		Reference branch;
		Repository repo_ptr;

		git_branch_t type = is_local ?
			GIT_BRANCH_LOCAL     :
			GIT_BRANCH_REMOTE    ;

	CODE:
		repo_ptr = GIT_SV_TO_PTR(Repository, repo);
		rc = git_branch_lookup(
			&branch, repo_ptr -> repository,
			SvPVbyte_nolen(name), type
		);

		if (rc == GIT_ENOTFOUND) {
			RETVAL = &PL_sv_undef;
		} else {
			git_check_error(rc);

			GIT_NEW_OBJ_WITH_MAGIC(
				RETVAL, SvPVbyte_nolen(class), branch, SvRV(repo)
			);
		}

	OUTPUT: RETVAL

void
move(self, name, force)
	SV *self
	SV *name
	bool force

	PREINIT:
		int rc;

		Branch new_branch;
		Branch old_branch;

	INIT:
		old_branch = GIT_SV_TO_PTR(Branch, self);

	CODE:
		rc = git_branch_move(
			&new_branch, old_branch, SvPVbyte_nolen(name), force
		);

		git_check_error(rc);

SV *
upstream(self, ...)
	SV *self

	PREINIT:
		int rc;

		Branch branch;
		Reference ref;

	CODE:
		branch = GIT_SV_TO_PTR(Branch, self);

		RETVAL = &PL_sv_undef;

		if (items == 2) {
			const char *name = NULL;

			if (SvOK(ST(1))) {
				if (sv_isobject(ST(1))) {
					if (sv_derived_from(ST(1), "Git::Raw::Reference"))
						name = git_reference_shorthand(GIT_SV_TO_PTR(Reference, ST(1)));
					else
						croak_usage("Invalid type for 'upstream'. Expected a 'Git::Raw::Reference' or "
							"'Git::Raw::Branch'");
				} else
					name = git_ensure_pv(ST(1), "upstream");
			}

			rc = git_branch_set_upstream(branch, name);
			git_check_error(rc);
		}

		rc = git_branch_upstream(&ref, branch);

		if (rc != GIT_ENOTFOUND) {
			git_check_error(rc);

			GIT_NEW_OBJ_WITH_MAGIC(
				RETVAL, "Git::Raw::Reference", ref, GIT_SV_TO_MAGIC(self)
			);
		}

	OUTPUT: RETVAL

SV *
upstream_name(self)
	SV *self

	PREINIT:
		int rc;

		Reference ref;
		git_buf buf = GIT_BUF_INIT_CONST(NULL, 0);

	CODE:
		RETVAL = &PL_sv_undef;

		ref = GIT_SV_TO_PTR(Reference, self);

		rc = git_branch_upstream_name(
				&buf,
				git_reference_owner(ref),
				git_reference_name(ref)
		);

		if (rc == GIT_OK)
			RETVAL = newSVpv(buf.ptr, buf.size);

		git_buf_dispose(&buf);

		if (rc != GIT_ENOTFOUND)
			git_check_error(rc);

	OUTPUT: RETVAL

SV *
remote_name(self)
	SV *self

	PREINIT:
		int rc;

		Reference ref;
		git_buf upstream = GIT_BUF_INIT_CONST(NULL, 0);
		git_buf remote = GIT_BUF_INIT_CONST(NULL, 0);

	CODE:
		RETVAL = &PL_sv_undef;

		ref = GIT_SV_TO_PTR(Reference, self);

		rc = git_branch_upstream_name(
				&upstream,
				git_reference_owner(ref),
				git_reference_name(ref)
		);

		if (rc == GIT_OK) {
			rc = git_branch_remote_name(
					&remote,
					git_reference_owner(ref),
					upstream.ptr);

			if (rc == GIT_OK)
				RETVAL = newSVpv(remote.ptr, remote.size);
		}

		git_buf_dispose(&upstream);
		git_buf_dispose(&remote);

		if (rc != GIT_ENOTFOUND)
			git_check_error(rc);

	OUTPUT: RETVAL

SV *
is_head(self)
	Branch self

	CODE:
		RETVAL = newSViv(git_branch_is_head(self));

	OUTPUT: RETVAL

void
DESTROY(self)
	SV *self

	CODE:
		git_reference_free(GIT_SV_TO_PTR(Reference, self));
		SvREFCNT_dec(GIT_SV_TO_MAGIC(self));
