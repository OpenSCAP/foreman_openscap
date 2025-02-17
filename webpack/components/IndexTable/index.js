import React from 'react';
import PropTypes from 'prop-types';
import {
	Table,
	TableHeader,
	TableBody
} from '@patternfly/react-table/deprecated';
import { Flex, FlexItem } from '@patternfly/react-core';
import Pagination from 'foremanReact/components/Pagination';
import { refreshPage } from './IndexTableHelper';

const IndexTable = ({
  history,
  pagination,
  totalCount,
  toolbarBtns,
  ariaTableLabel,
  ouiaTableId,
  columns,
  ...rest
}) => {
  const handlePerPageSelected = perPage => {
    refreshPage(history, { page: 1, perPage });
  };

  const handlePageSelected = page => {
    refreshPage(history, { ...pagination, page });
  };

  return (
    <React.Fragment>
      <Flex className="pf-v5-u-pt-md">
        <FlexItem>{toolbarBtns}</FlexItem>
        <FlexItem align={{ default: 'alignRight' }}>
          <Pagination
            itemCount={totalCount}
            page={pagination.page}
            perPage={pagination.perPage}
            onSetPage={handlePageSelected}
            onPerPageSelect={handlePerPageSelected}
            variant="top"
          />
        </FlexItem>
      </Flex>
      <Table
        ouiaId={ouiaTableId}
        aria-label={ariaTableLabel}
        cells={columns}
        {...rest}
        variant="compact"
      >
        <TableHeader />
        <TableBody />
      </Table>
    </React.Fragment>
  );
};

IndexTable.propTypes = {
  history: PropTypes.object.isRequired,
  pagination: PropTypes.object.isRequired,
  toolbarBtns: PropTypes.node,
  totalCount: PropTypes.number.isRequired,
  ariaTableLabel: PropTypes.string.isRequired,
  ouiaTableId: PropTypes.string.isRequired,
  columns: PropTypes.array.isRequired,
};

IndexTable.defaultProps = {
  toolbarBtns: null,
};

export default IndexTable;
