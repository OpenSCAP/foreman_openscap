/* eslint-disable camelcase */
import React, { useContext, useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import {
  Spinner,
  Toolbar,
  ToolbarContent,
  ToolbarGroup,
  ToolbarItem,
  Button,
} from '@patternfly/react-core';
import { Td } from '@patternfly/react-table';
import { toArray } from 'lodash';

import { foremanUrl } from 'foremanReact/common/helpers';
import { translate as __ } from 'foremanReact/common/I18n';
import SelectAllCheckbox from 'foremanReact/components/PF4/TableIndexPage/Table/SelectAllCheckbox';
import { Table } from 'foremanReact/components/PF4/TableIndexPage/Table/Table';
import { useBulkSelect } from 'foremanReact/components/PF4/TableIndexPage/Table/TableHooks';
import { getPageStats } from 'foremanReact/components/PF4/TableIndexPage/Table/helpers';
import { STATUS } from 'foremanReact/constants';
import { useAPI } from 'foremanReact/common/hooks/API/APIHooks';
import { useForemanHostDetailsPageUrl } from 'foremanReact/Root/Context/ForemanContext';

import OpenscapRemediationWizardContext from '../OpenscapRemediationWizardContext';
import WizardHeader from '../WizardHeader';
import { HOSTS_API_PATH, HOSTS_API_REQUEST_KEY } from '../constants';

const ReviewHosts = () => {
  const {
    hostId,
    setHostIdsParam,
    defaultFailedHostsSearch,
    setIsAllHostsSelected,
    savedHostSelectionsRef,
  } = useContext(OpenscapRemediationWizardContext);

  const defaultParams = {
    search: defaultFailedHostsSearch,
  };
  const defaultHostsArry = [hostId];

  const [params, setParams] = useState(defaultParams);

  const response = useAPI('get', `${HOSTS_API_PATH}?include_permissions=true`, {
    key: HOSTS_API_REQUEST_KEY,
    params: defaultParams,
  });
  const {
    response: {
      search: apiSearchQuery,
      results,
      per_page: perPage,
      page,
      subtotal,
      message: errorMessage,
    },
    status = STATUS.PENDING,
    setAPIOptions,
  } = response;

  const subtotalCount = Number(subtotal ?? 0);

  const setParamsAndAPI = newParams => {
    setParams(newParams);
    setAPIOptions({ key: HOSTS_API_REQUEST_KEY, params: newParams });
  };

  const { pageRowCount } = getPageStats({
    total: subtotalCount,
    page,
    perPage,
  });
  const { fetchBulkParams, ...selectAllOptions } = useBulkSelect({
    results,
    metadata: { total: subtotalCount, page },
    initialSearchQuery: apiSearchQuery || defaultFailedHostsSearch,
    isSelectable: () => true,
    defaultArry: defaultHostsArry,
    initialArry: toArray(
      savedHostSelectionsRef.current.inclusionSet || defaultHostsArry
    ),
    initialExclusionArry: toArray(
      savedHostSelectionsRef.current.exclusionSet || []
    ),
    initialSelectAllMode: savedHostSelectionsRef.current.selectAllMode || false,
  });
  const {
    selectPage,
    selectedCount,
    selectOne,
    selectNone,
    selectDefault,
    selectAll,
    areAllRowsOnPageSelected,
    areAllRowsSelected,
    isSelected,
    inclusionSet,
    exclusionSet,
    selectAllMode,
  } = selectAllOptions;

  useEffect(() => {
    if (selectedCount) {
      setHostIdsParam(fetchBulkParams());
      savedHostSelectionsRef.current = {
        inclusionSet,
        exclusionSet,
        selectAllMode,
      };
    }
  }, [selectedCount, fetchBulkParams, setHostIdsParam]);

  const selectionToolbar = (
    <ToolbarItem key="selectAll">
      <SelectAllCheckbox
        {...{
          selectAll: () => {
            selectAll(true);
            setIsAllHostsSelected(true);
          },
          selectPage: () => {
            selectPage();
            setIsAllHostsSelected(false);
          },
          selectDefault: () => {
            selectDefault();
            setIsAllHostsSelected(false);
          },
          selectNone: () => {
            selectNone();
            setIsAllHostsSelected(false);
          },
          selectedCount,
          pageRowCount,
        }}
        totalCount={subtotalCount}
        selectedDefaultCount={1} // The default host (hostId) is always selected
        areAllRowsOnPageSelected={areAllRowsOnPageSelected()}
        areAllRowsSelected={areAllRowsSelected()}
      />
    </ToolbarItem>
  );

  const RowSelectTd = ({ rowData }) => (
    <Td
      select={{
        rowIndex: rowData.id,
        onSelect: (_event, isSelecting) => {
          selectOne(isSelecting, rowData.id, rowData);
          // If at least one was unselected, then it's not all selected
          if (!isSelecting) setIsAllHostsSelected(false);
        },
        isSelected: rowData.id === hostId || isSelected(rowData.id),
        isDisabled: rowData.id === hostId || false,
      }}
    />
  );
  RowSelectTd.propTypes = {
    rowData: PropTypes.object.isRequired,
  };

  const hostDetailsURL = useForemanHostDetailsPageUrl();
  const columns = {
    name: {
      title: __('Name'),
      wrapper: ({ name, display_name: displayName }) => (
        <Button
          ouiaId={`oscap-rem-wiz-ext-link-to-host-${name}-revhst-step`}
          component="a"
          variant="link"
          target="_blank"
          href={foremanUrl(`${hostDetailsURL}${name}`)}
        >
          {displayName}
        </Button>
      ),
      isSorted: true,
      weight: 50,
      isRequired: true,
    },
    os_title: {
      title: __('OS'),
      wrapper: hostDetails => hostDetails?.operatingsystem_name,
      isSorted: true,
      weight: 200,
    },
  };

  return (
    <>
      <WizardHeader
        title={__('Review hosts')}
        description={__(
          'By default, remediation is applied to the current host. Optionally, remediate any additional hosts that fail the rule.'
        )}
      />
      <Toolbar ouiaId="table-toolbar" className="table-toolbar">
        <ToolbarContent>
          <ToolbarGroup>
            {selectionToolbar}
            {status === STATUS.PENDING && (
              <ToolbarItem>
                <Spinner size="sm" />
              </ToolbarItem>
            )}
          </ToolbarGroup>
        </ToolbarContent>
      </Toolbar>
      <Table
        ouiaId="hosts-review-table"
        isEmbedded
        params={params}
        setParams={setParamsAndAPI}
        itemCount={subtotalCount}
        results={results}
        url={HOSTS_API_PATH}
        refreshData={() =>
          setAPIOptions({
            key: HOSTS_API_REQUEST_KEY,
            params: { defaultFailedHostsSearch },
          })
        }
        columns={columns}
        errorMessage={
          status === STATUS.ERROR && errorMessage ? errorMessage : null
        }
        isPending={status === STATUS.PENDING}
        showCheckboxes
        rowSelectTd={RowSelectTd}
      />
    </>
  );
};

export default ReviewHosts;
